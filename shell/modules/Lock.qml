import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

// quartz — lock screen. A real ext-session-lock: while locked the compositor
// shows nothing else, and if quartz dies locked the screen STAYS locked.
// Triggers: `loginctl lock-session` (Super+L, hypridle, before sleep) via a
// logind signal watcher, the power menu, `qs -c quartz ipc call quartz lock`.
// Unlock only via PAM ("login" stack) or `loginctl unlock-session`.
Scope {
    id: root

    readonly property bool locked: lock.locked
    property string password: ""
    property string error: ""
    property bool busy: pam.active
    property bool unlocking: false
    property int fails: 0
    signal failed

    function lockNow() {
        if (lock.locked)
            return;
        root.password = "";
        root.error = "";
        root.unlocking = false;
        lock.locked = true;
    }
    function submit() {
        if (pam.active || !root.password.length)
            return;
        root.error = "";
        pam.start();
    }
    // Let the surfaces fade out, then release the lock.
    function release() {
        root.unlocking = true;
        unlockTimer.restart();
    }
    Timer {
        id: unlockTimer
        interval: 380
        onTriggered: {
            lock.locked = false;
            root.unlocking = false;
            root.password = "";
            root.fails = 0;
        }
    }

    WlSessionLock {
        id: lock
        LockSurface {
            ctx: root
        }
    }

    PamContext {
        id: pam
        config: "login"
        onResponseRequiredChanged: {
            if (responseRequired) {
                respond(root.password);
            }
        }
        onPamMessage: {
            if (messageIsError && message.length)
                root.error = message;
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.release();
            } else {
                root.password = "";
                root.fails++;
                if (!root.error.length)
                    root.error = "Wrong password";
                root.failed();
            }
        }
        onError: {
            root.password = "";
            root.error = "Couldn't check the password";
            root.failed();
        }
    }
    Timer {
        // a hung PAM module must not wedge the field forever (fail closed)
        interval: 12000
        running: pam.active
        onTriggered: {
            pam.abort();
            root.password = "";
            root.error = "Timed out — try again";
            root.failed();
        }
    }

    // ── logind: loginctl lock-session / unlock-session → this lock ──
    Process {
        id: logind
        running: true
        property bool scoped: false
        property int fails: 0
        property double started: Date.now()
        command: ["setpriv", "--pdeathsig", "TERM", "--", "sh", "-c",
            'p=""; [ -n "$XDG_SESSION_ID" ] && p=$(busctl --system call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager GetSession s "$XDG_SESSION_ID" 2>/dev/null | cut -d\'"\' -f2); ' +
            '[ -z "$p" ] && p=$(busctl --system call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager GetSessionByPID u $$ 2>/dev/null | cut -d\'"\' -f2); ' +
            'if [ -n "$p" ]; then echo QUARTZ_SCOPED; exec gdbus monitor --system --dest org.freedesktop.login1 --object-path "$p"; fi; ' +
            'echo QUARTZ_UNSCOPED; exec gdbus monitor --system --dest org.freedesktop.login1']
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("QUARTZ_SCOPED") >= 0)
                    logind.scoped = true;
                else if (line.indexOf("QUARTZ_UNSCOPED") >= 0)
                    logind.scoped = false;
                else if (line.indexOf(".Session.Unlock (") >= 0) {
                    if (logind.scoped && lock.locked)
                        root.release();
                } else if (line.indexOf(".Session.Lock (") >= 0)
                    root.lockNow();
            }
        }
        onRunningChanged: if (running) started = Date.now()
        onExited: {
            fails = (Date.now() - started < 3000) ? fails + 1 : 0;
            if (fails <= 6)
                relaunch.restart();
        }
    }
    Timer {
        id: relaunch
        interval: Math.min(30000, 2000 * Math.pow(2, Math.min(logind.fails, 4)))
        onTriggered: {
            logind.scoped = false;
            logind.running = true;
        }
    }
}
