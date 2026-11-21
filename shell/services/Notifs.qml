pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../core"

// quartz — the notification daemon. Two lists of ids, newest first:
//   toasts  — on screen right now (each times out on its own)
//   history — the notification centre (until dismissed or the app closes it)
Singleton {
    id: root

    readonly property ListModel toasts: toastModel
    readonly property ListModel history: historyModel
    readonly property int count: historyModel.count
    readonly property bool dnd: Config.opt.dnd
    property var objs: ({})
    property var times: ({})

    function get(id) { return root.objs[id] ?? null; }

    // A path, URL or theme icon name → something an Image can show, or "" when
    // the icon theme doesn't have it (so the card falls back to a glyph
    // instead of Qt's magenta "missing" square).
    function resolve(src) {
        if (!src || !src.length)
            return "";
        if (src.startsWith("/"))
            return "file://" + src;
        if (src.startsWith("image://icon/"))
            return Quickshell.iconPath(src.substring(13).split("?")[0], true);
        if (src.indexOf("://") > 0)
            return src;
        return Quickshell.iconPath(src, true);
    }
    function iconFor(n) {
        if (!n)
            return "";
        const ai = resolve(n.appIcon ?? "");
        if (ai.length)
            return ai;
        const de = n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : DesktopEntries.heuristicLookup(n.appName ?? "");
        return (de && de.icon) ? Quickshell.iconPath(de.icon, true) : "";
    }
    function imageFor(n) { return resolve(n?.image ?? ""); }
    function glyphFor(n) {
        const s = ((n?.appIcon ?? "") + " " + (n?.image ?? "")).toLowerCase();
        if (s.indexOf("error") >= 0) return "error";
        if (s.indexOf("warning") >= 0) return "warning";
        if (s.indexOf("information") >= 0 || s.indexOf("info") >= 0) return "info";
        return "notifications";
    }
    function ago(id, now) {
        const t = root.times[id];
        if (!t)
            return "";
        const s = Math.floor((now - t) / 1000);
        if (s < 60)
            return "now";
        if (s < 3600)
            return Math.floor(s / 60) + "m";
        if (s < 86400)
            return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    function removeFrom(model, id) {
        for (let i = model.count - 1; i >= 0; i--)
            if (model.get(i).nid === id)
                model.remove(i);
    }
    function drop(id) {
        removeFrom(toastModel, id);
        removeFrom(historyModel, id);
        delete root.objs[id];
        delete root.times[id];
    }
    function hideToast(id) { removeFrom(toastModel, id); }
    function dismiss(id) {
        const n = get(id);
        if (n)
            n.dismiss();
        drop(id);
    }
    function clearAll() {
        const ids = [];
        for (let i = 0; i < historyModel.count; i++)
            ids.push(historyModel.get(i).nid);
        for (const id of ids)
            dismiss(id);
    }

    function add(n) {
        const id = n.id;
        const isNew = !root.objs[id];
        root.objs[id] = n;
        root.times[id] = Date.now();
        removeFrom(toastModel, id);
        removeFrom(historyModel, id);
        historyModel.insert(0, { nid: id });
        const urgent = n.urgency === NotificationUrgency.Critical;
        if (!n.lastGeneration && (!root.dnd || urgent))
            toastModel.insert(0, { nid: id });
        if (isNew)
            n.closed.connect(() => root.drop(id));
        // Chat apps rarely close what they send: cap the live set.
        while (historyModel.count > 60) {
            const old = historyModel.get(historyModel.count - 1).nid;
            const o = get(old);
            if (o)
                o.expire();
            drop(old);
        }
        while (toastModel.count > 4)
            toastModel.remove(toastModel.count - 1);
    }

    SystemClock {
        id: clk
        precision: SystemClock.Minutes
    }
    readonly property date now: clk.date

    ListModel { id: toastModel }
    ListModel { id: historyModel }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: n => {
            n.tracked = true;
            root.add(n);
        }
    }
}
