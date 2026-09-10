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
        toastVisible: false, toastQueue: [], currentEntryId: -1
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
console.log("Notification regressions passed");
