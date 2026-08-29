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
            summary: "CPU-, RAM- es lemezhasznalat.",
            streams: true,
            methods: Vec::new(),
        }
    }

    async fn run(self: Arc<Self>, sink: StateSink) -> Result<()> {
        let mut cpu = CpuSampler::default();
        let mut disk_usage = disk_usage_percent();
        let mut disk_checked = Instant::now();

        // Az elso CPU-minta meg nem ad hasznalati szazalekot: kell hozza ket
        // pont. Ezert azonnal kikuldunk egy kezdo allapotot, majd tickelunk.
        cpu.sample();

        loop {
            tokio::time::sleep(TICK).await;

            if disk_checked.elapsed() >= DISK_EVERY {
                disk_usage = disk_usage_percent();
                disk_checked = Instant::now();
            }

            sink.push(json!({
                "cpuUsage": cpu.sample().unwrap_or(0),
                "ramUsage": ram_usage_percent(),
                "diskUsage": disk_usage,
            }));
        }
    }
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

fn ram_usage_percent() -> u32 {
    let Ok(text) = std::fs::read_to_string("/proc/meminfo") else {
        return 0;
    };

    let value_of = |key: &str| -> Option<u64> {
        text.lines()
            .find(|line| line.starts_with(key))?
            .split_whitespace()
            .nth(1)?
            .parse()
            .ok()
    };

    match (value_of("MemTotal:"), value_of("MemAvailable:")) {
        (Some(total), Some(available)) if total > 0 => {
            ((total.saturating_sub(available)) * 100 / total).min(100) as u32
        }
        _ => 0,
    }
}

/// A gyoker fajlrendszer telitettsege. A `df` helyett `statvfs`, ugyanazzal a
/// szamitassal, amit a `df` hasznal (a rootnak fenntartott blokkok nelkul).
fn disk_usage_percent() -> u32 {
    let mut stat: libc_statvfs = unsafe { std::mem::zeroed() };
    let path = c"/";

    // SAFETY: a `path` ervenyes, NUL-lal lezart C string, a `stat` pedig egy
    // megfeleloen meretezett, irhato buffer.
    if unsafe { statvfs(path.as_ptr(), &mut stat) } != 0 {
        return 0;
    }

    let total = stat.f_blocks.saturating_sub(stat.f_bfree);
    let usable = total + stat.f_bavail;
    if usable == 0 {
        return 0;
    }
    ((total * 100 + usable - 1) / usable).min(100) as u32
}

// A statvfs az egyetlen libc hivas, amiert nem eri meg behuzni a teljes cratet.
#[repr(C)]
#[allow(non_camel_case_types)]
struct libc_statvfs {
    f_bsize: u64,
    f_frsize: u64,
    f_blocks: u64,
    f_bfree: u64,
    f_bavail: u64,
    f_files: u64,
    f_ffree: u64,
    f_favail: u64,
    f_fsid: u64,
    f_flag: u64,
    f_namemax: u64,
    f_spare: [i32; 6],
}

unsafe extern "C" {
    fn statvfs(path: *const std::ffi::c_char, buf: *mut libc_statvfs) -> i32;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ram_usage_is_a_percentage() {
        let usage = ram_usage_percent();
        assert!(usage <= 100, "ertelmetlen RAM szazalek: {usage}");
    }

    #[test]
    fn disk_usage_is_a_percentage() {
        let usage = disk_usage_percent();
        assert!(usage > 0 && usage <= 100, "ertelmetlen lemez szazalek: {usage}");
    }

    #[test]
    fn cpu_needs_two_samples() {
        let mut sampler = CpuSampler::default();
        assert_eq!(sampler.sample(), None, "az elso minta meg nem adhat erteket");
        std::thread::sleep(Duration::from_millis(50));
        assert!(sampler.sample().is_some(), "a masodik mintanak mar adnia kell");
    }
}
