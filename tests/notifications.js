// A tenyleges controller fuggvenyeit futtatjuk szolgaltatasregisztracio nelkul.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");

const source = fs.readFileSync(path.join(__dirname,
    "../features/notifications/NotificationsController.qml"), "utf8");
const functions = [...source.matchAll(/^    function [\s\S]*?^    }/gm)]
    .map(match => match[0]).join("\n");

function controller() {
    const context = vm.createContext({
        history: [], groups: [], expandedGroups: Object.create(null),
        groupingEnabled: true, unreadCount: 0, menuOpened: false,
        toastVisible: false, toastQueue: [], currentEntryId: -1,
        historyLimit: 100, nextEntryId: 1, dnd: false, storeLoaded: false
    });
    vm.runInContext(functions, context);
    return context;
}

function entry(id, appName, unread = true) {
    return {id, appName, unread, icon: "", time: "12:00", notification: null};
}

for (const appName of ["__proto__", "constructor", "hasownproperty", "Normal"]) {
    const c = controller();
    c.history = [entry(1, appName), entry(2, appName), entry(3, "Other")];
    c.rebuildGroups();
    assert.equal(c.groups.length, 2, appName);
    assert.equal(c.groups[0].entries.length, 2, appName);
    const key = c.groups[0].key;
    c.setGroupExpanded(key, true);
    assert.equal(c.groups[0].expanded, true, appName);
    c.setAllGroupsExpanded(false);
    assert.equal(c.groups[0].expanded, false, appName);
}

const c = controller();
c.history = [entry(1, "Mail"), entry(2, "Mail")];
c.unreadCount = 2;
c.setMenuOpen(true);
c.rebuildGroups(); // A QML-ben ezt az onHistoryChanged hivja.
assert.equal(c.unreadCount, 0);
assert.equal(c.groups[0].unread, 0);
assert.ok(c.history.every(item => !item.unread));
c.setMenuOpen(false);
c.history.push(entry(3, "Mail"));
c.unreadCount++;
c.removeHistory(1, false);
assert.equal(c.unreadCount, 1, "regi ertesites torlese nem fogyaszthatja az uj szamlalojat");
// Az elozmeny mentese es visszatoltese: csak sima mezok, el nem mulo ikonok.
{
    const saved = controller();
    const live = {id: 7, appName: "Mail", summary: "<b>Hi</b>", body: "code 123456",
        icon: "image://qsimage/42", critical: true, time: "09:15", unread: true,
        notification: {dismiss() {}}, actions: [{}], defaultAction: {}};
    const themed = {...entry(8, "Chat", false), icon: "image://icon/chat"};
    const stored = JSON.parse(JSON.stringify(saved.storedHistory([live, themed])));
    assert.equal(stored[0].icon, "", "a kepadat-ikon egy uj shellben mar nem letezik");
    assert.equal(stored[1].icon, "image://icon/chat");
    assert.equal(stored[0].notification, undefined);
    assert.equal(stored[0].summary, "<b>Hi</b>", "a szoveg valtozatlan, PlainTextkent jelenik meg");

    const restoredController = controller();
    restoredController.history = [entry(1, "New", true)];
    restoredController.nextEntryId = 2;
    restoredController.applyStored(JSON.stringify({version: 1, dnd: true,
        history: stored.concat([null, "junk", {appName: 5}])}));
    const restored = restoredController.history;
    assert.equal(restored.length, 4, "a betoltes elott jott ertesites megmarad, a szemet kiesik");
    assert.equal(restored[0].appName, "New");
    assert.equal(restored[1].critical, true);
    assert.equal(restored[1].notification, null);
    assert.deepEqual(Array.from(restored[1].actions), []);
    assert.equal(restored[3].appName, "5");
    assert.equal(new Set(restored.map(item => item.id)).size, 4, "egyedi azonositok");
    assert.equal(restoredController.unreadCount, 2);
    assert.equal(restoredController.dnd, true);
    assert.equal(restoredController.storeLoaded, true);

    const broken = controller();
    broken.applyStored("{not json");
    assert.equal(broken.history.length, 0);
    assert.equal(broken.storeLoaded, true, "hibas fajl utan is ment tovabb");
}

console.log("Notification regressions passed");
