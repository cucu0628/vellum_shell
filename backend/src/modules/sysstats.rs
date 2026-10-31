//! CPU-, memoria- es lemezhasznalat.
//!
//! A `df -P /` processzinditas eltunt; a CPU es a memoria eddig is `/proc`-bol
//! jott, es a lazy topic miatt ez a hurok csak akkor fut, ha valaki nezi.
//!
//! A halozati atvitel SZANDEKOSAN nem ide tartozik: azt a QML
//! `ThroughputController` az AKTIV interfeszre meri, mig egy osszesites VPN
//! alagut mellett duplan szamolna. Az a controller amugy is `FileView`-t
//! hasznal, tehat nincs benne processzinditas, amit meg lehetne sporolni.

use crate::module::{Module, ModuleDescription, StateSink};
use anyhow::Result;
use async_trait::async_trait;
use serde_json::json;
use std::sync::Arc;
use std::time::{Duration, Instant};

const TICK: Duration = Duration::from_secs(1);
/// A lemez lassan valtozik; felesleges masodpercenkent statvfs-t hivni.
const DISK_EVERY: Duration = Duration::from_secs(60);

pub struct SysStats;

impl Default for SysStats {
    fn default() -> Self {
        Self::new()
    }
}

impl SysStats {
    pub fn new() -> Self {
        Self
    }
}

#[async_trait]
impl Module for SysStats {
    fn name(&self) -> &'static str {
        "sysstats"
    }

    fn describe(&self) -> ModuleDescription {
        ModuleDescription {
            topic: "sysstats",
            summary: "CPU-, RAM- es lemezhasznalat, uptime.",
            streams: true,
            methods: Vec::new(),
        }
    }

    async fn run(self: Arc<Self>, sink: StateSink) -> Result<()> {
        let mut cpu = CpuSampler::default();
        let mut disk = Disk::read();
        let mut disk_checked = Instant::now();

        // Az elso CPU-minta meg nem ad hasznalati szazalekot: kell hozza ket
        // pont. Ezert a CPU nullaval indul, de a RAM es a lemez mar most valos
        // -- igy a feliratkozonak nincs egy masodperces ures ablaka.
        cpu.sample();
        sink.push(payload(0, &Memory::read(), &disk));

        loop {
            tokio::time::sleep(TICK).await;

            if disk_checked.elapsed() >= DISK_EVERY {
                disk = Disk::read();
                disk_checked = Instant::now();
            }

            sink.push(payload(cpu.sample().unwrap_or(0), &Memory::read(), &disk));
        }
    }
}

/// A topic egy allapota. A harom szazalek a regi szerzodes; a GiB-ertekek es
/// az uptime kesobbi, visszafele kompatibilis bovites.
fn payload(cpu_usage: u32, memory: &Memory, disk: &Disk) -> serde_json::Value {
    json!({
        "cpuUsage": cpu_usage,
        "ramUsage": memory.percent(),
        "diskUsage": disk.percent(),
        "ramUsedGib": gib(memory.used_bytes()),
        "ramTotalGib": gib(memory.total_bytes()),
        "diskUsedGib": gib(disk.used_bytes()),
        "diskTotalGib": gib(disk.usable_bytes()),
        "uptimeSeconds": uptime_seconds(),
    })
}

/// Egy tizedesre kerekitett GiB.
fn gib(bytes: u64) -> f64 {
    (bytes as f64 / 1024f64.powi(3) * 10.0).round() / 10.0
}

/// Ket egymast koveto `/proc/stat` minta kulonbsegebol szamol.
#[derive(Default)]
struct CpuSampler {
    previous_idle: Option<u64>,
    previous_total: Option<u64>,
}

impl CpuSampler {
    fn sample(&mut self) -> Option<u32> {
        let text = std::fs::read_to_string("/proc/stat").ok()?;
        let line = text.lines().next()?;
        let mut fields = line.split_whitespace();
        if fields.next()? != "cpu" {
            return None;
        }

        let values: Vec<u64> = fields.filter_map(|value| value.parse().ok()).collect();
        if values.len() < 5 {
            return None;
        }

        // idle + iowait, ugyanaz a felbontas, mint a korabbi QML szamolasban.
        let idle = values[3] + values[4];
        let total: u64 = values.iter().sum();

        let usage = match (self.previous_idle, self.previous_total) {
            (Some(previous_idle), Some(previous_total)) if total > previous_total => {
                let idle_delta = idle.saturating_sub(previous_idle) as f64;
                let total_delta = (total - previous_total) as f64;
                Some(((1.0 - idle_delta / total_delta) * 100.0).clamp(0.0, 100.0).round() as u32)
            }
            _ => None,
        };

        self.previous_idle = Some(idle);
        self.previous_total = Some(total);
        usage
    }
}

/// A `/proc/meminfo` ket sora, kibibyte-ban.
#[derive(Default)]
struct Memory {
    total_kib: u64,
    available_kib: u64,
}

impl Memory {
    fn read() -> Self {
        let Ok(text) = std::fs::read_to_string("/proc/meminfo") else {
            return Self::default();
        };

        let value_of = |key: &str| -> Option<u64> {
            text.lines().find(|line| line.starts_with(key))?.split_whitespace().nth(1)?.parse().ok()
        };

        match (value_of("MemTotal:"), value_of("MemAvailable:")) {
            (Some(total_kib), Some(available_kib)) => Self { total_kib, available_kib },
            _ => Self::default(),
        }
    }

    fn used_kib(&self) -> u64 {
        self.total_kib.saturating_sub(self.available_kib)
    }

    fn used_bytes(&self) -> u64 {
        self.used_kib() * 1024
    }

    fn total_bytes(&self) -> u64 {
        self.total_kib * 1024
    }

    fn percent(&self) -> u32 {
        if self.total_kib == 0 {
            return 0;
        }
        (self.used_kib() * 100 / self.total_kib).min(100) as u32
    }
}

/// A gyoker fajlrendszer telitettsege. A `df` helyett `statvfs`, ugyanazzal a
/// szamitassal, amit a `df` hasznal (a rootnak fenntartott blokkok nelkul).
#[derive(Default)]
struct Disk {
    used_blocks: u64,
    usable_blocks: u64,
    block_size: u64,
}

impl Disk {
    fn read() -> Self {
        let mut stat: libc::statvfs = unsafe { std::mem::zeroed() };
        let path = c"/";

        // SAFETY: a `path` ervenyes, NUL-lal lezart C string, a `stat` pedig egy
        // megfeleloen meretezett, irhato buffer.
        if unsafe { libc::statvfs(path.as_ptr(), &mut stat) } != 0 {
            return Self::default();
        }

        let used_blocks = stat.f_blocks.saturating_sub(stat.f_bfree);
        Self { used_blocks, usable_blocks: used_blocks + stat.f_bavail, block_size: stat.f_frsize }
    }

    fn used_bytes(&self) -> u64 {
        self.used_blocks * self.block_size
    }

    fn usable_bytes(&self) -> u64 {
        self.usable_blocks * self.block_size
    }

    fn percent(&self) -> u32 {
        if self.usable_blocks == 0 {
            return 0;
        }
        (self.used_blocks * 100).div_ceil(self.usable_blocks).min(100) as u32
    }
}

/// A rendszer futasi ideje masodpercben, a `/proc/uptime` elso mezojebol.
fn uptime_seconds() -> u64 {
    std::fs::read_to_string("/proc/uptime")
        .ok()
        .and_then(|text| text.split_whitespace().next()?.parse::<f64>().ok())
        .map_or(0, |seconds| seconds as u64)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ram_usage_is_a_percentage() {
        let memory = Memory::read();
        assert!(memory.percent() <= 100, "ertelmetlen RAM szazalek: {}", memory.percent());
        assert!(memory.used_bytes() <= memory.total_bytes());
    }

    #[test]
    fn disk_usage_is_a_percentage() {
        let disk = Disk::read();
        let usage = disk.percent();
        assert!(usage > 0 && usage <= 100, "ertelmetlen lemez szazalek: {usage}");
        assert!(disk.used_bytes() <= disk.usable_bytes());
    }

    #[test]
    fn payload_keeps_the_original_fields() {
        let value = payload(7, &Memory::read(), &Disk::read());
        for key in ["cpuUsage", "ramUsage", "diskUsage", "ramTotalGib", "uptimeSeconds"] {
            assert!(value.get(key).is_some(), "hianyzik: {key}");
        }
        assert_eq!(value["cpuUsage"], 7);
    }

    #[test]
    fn gib_rounds_to_one_decimal() {
        assert_eq!(gib(1024 * 1024 * 1024), 1.0);
        assert_eq!(gib(1610612736), 1.5);
    }

    #[test]
    fn cpu_needs_two_samples() {
        let mut sampler = CpuSampler::default();
        assert_eq!(sampler.sample(), None, "az elso minta meg nem adhat erteket");
        std::thread::sleep(Duration::from_millis(50));
        assert!(sampler.sample().is_some(), "a masodik mintanak mar adnia kell");
    }
}
