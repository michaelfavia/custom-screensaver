/*
 * DVD Corner Plasma screensaver.
 *
 * Usage:
 *   mount --bind ./screensaver-main.qml /usr/palm/applications/com.webos.app.screensaver/qml/main.qml
 *
 * Test launch (no way to trigger on "No signal" screen)
 *   luna-send -n 1 'luna://com.webos.service.tvpower/power/turnOnScreenSaver' '{}'
 */
import QtQuick 2.4
import Eos.Window 0.1

// DVD Corner Plasma: the classic bouncing DVD logo (same size and speed as webosbrew/custom-screensaver).
// A normal wall bounce changes its color. A corner hit (one wall reached within NEAR px of the other) flashes
// the screen, sends rainbow ripples out from the logo like water, and drags a rainbow plasma tail behind the
// logo until it reaches the next wall. The path repeats every 1330.56 s; with NEAR = 10 that is 3 corners a loop.
// The ripples and the tail are each one shader drawn at 960x540 and only while they show.
WebOSWindow {
    id: win
    width: 1920
    height: 1080
    windowType: "_WEBOS_WINDOW_TYPE_SCREENSAVER"
    appId: "com.webos.app.screensaver"
    title: "Screen Saver"
    visible: true
    color: "black"

    property int level: 1                         // 0 dim, 1 bright
    property real bright: level ? 1.0 : 0.6

    readonly property int bw: 320
    readonly property int bh: 163
    readonly property real xt: 1920 * 11          // ms per left-right leg (as the original)
    readonly property real yt: 1080 * 7           // ms per top-bottom leg
    readonly property real cycle: xt * 63         // the whole path repeats
    readonly property int near: 10

    property real t: Math.random() * cycle        // ms along the path; random start each run
    property real ox: 0                           // per-axis time offsets: a near-corner nudges the other axis
    property real oy: 0                           //   onto its wall too, so it is a true corner and bounces straight out
    property int lx: 0                            // current leg on each axis
    property int ly: 0
    property real bx: 0
    property real by: 0
    property color tint: "#ffff00"

    // effect state, all in ms of t
    property bool plasma: false
    property real hitT: -1e9                      // last corner hit
    property real fadeT: -1e9                     // when the plasma stopped (next wall)
    property real sx: 0                           // tail start (logo center at the hit)
    property real sy: 0
    property real hue: 0                          // 0..1, turns while the plasma runs

    readonly property var colors: ["#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff", "#00ffff", "#ffffff"]

    function tri(tt, T, span) { var p = tt % (2 * T); return p < T ? p / T * span : (2 - p / T) * span; }

    function step() {
        t += 33;
        var hitX = Math.floor((t + ox) / xt) !== lx;
        var hitY = Math.floor((t + oy) / yt) !== ly;
        bx = tri(t + ox, xt, width - bw);
        by = tri(t + oy, yt, height - bh);
        var nearX = bx <= near || bx >= width - bw - near;
        var nearY = by <= near || by >= height - bh - near;
        if ((hitX && nearY) || (hitY && nearX)) {
            // put the other axis on its wall too, the same few ms past the bounce, so both turn around together
            var e, a;
            if (hitX && !hitY) { e = t + ox - Math.floor((t + ox) / xt) * xt; a = t + oy; oy += Math.round(a / yt) * yt + e - a; }
            else if (hitY && !hitX) { e = t + oy - Math.floor((t + oy) / yt) * yt; a = t + ox; ox += Math.round(a / xt) * xt + e - a; }
            bx = tri(t + ox, xt, width - bw);
            by = tri(t + oy, yt, height - bh);
            corner();
        }
        else if (hitX || hitY) wall();
        if (plasma) { hue = (hue + 0.033 * 240 / 360) % 1; tint = Qt.hsla(hue, 1, 0.6, 1); }
        if (t > cycle * 4) { t -= cycle * 4; hitT -= cycle * 4; fadeT -= cycle * 4; }   // keep floats small (a whole number of bounces)
        ox = ox % (2 * xt); oy = oy % (2 * yt);
        lx = Math.floor((t + ox) / xt); ly = Math.floor((t + oy) / yt);
    }
    function corner() {
        hitT = t; plasma = true;
        sx = bx + bw / 2; sy = by + bh / 2;
        flashAnim.restart();
    }
    function wall() {
        if (plasma) { plasma = false; fadeT = t; }
        tint = colors[Math.floor(Math.random() * colors.length)];
    }

    Timer { interval: 33; running: true; repeat: true; onTriggered: win.step() }
    Component.onCompleted: { tint = colors[Math.floor(Math.random() * colors.length)]; lx = Math.floor(t / xt); ly = Math.floor(t / yt); step(); }

    // ---------- rainbow plasma tail: a ribbon along the logo's straight path since the corner ----------
    Item {
        width: 960; height: 540; scale: 2; transformOrigin: Item.TopLeft
        visible: win.plasma || (win.t - win.fadeT) < 1500
        ShaderEffect {
            anchors.fill: parent
            property real age: (win.t - win.hitT) / 1000          // s since the corner
            property real fade: win.plasma ? 1.0 : Math.max(0, 1 - (win.t - win.fadeT) / 1500)
            property real now: win.t / 1000
            property point s: Qt.point(win.sx, win.sy)
            property point p: Qt.point(win.bx + win.bw / 2, win.by + win.bh / 2)
            property real hue0: win.hue
            property real bright: win.bright
            fragmentShader: "
                #ifdef GL_ES
                precision mediump float;
                #endif
                varying highp vec2 qt_TexCoord0;
                uniform lowp float qt_Opacity;
                uniform float age; uniform float fade; uniform float now; uniform float hue0; uniform float bright;
                uniform vec2 s; uniform vec2 p;
                vec3 hsv(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }
                void main() {
                    vec2 q = qt_TexCoord0 * vec2(1920.0, 1080.0);
                    vec2 v = p - s; float L = max(length(v), 1.0); vec2 dir = v / L; vec2 nrm = vec2(-dir.y, dir.x);
                    float u = clamp(dot(q - s, dir) / L, 0.0, 1.0);          // 0 at the corner, 1 at the logo
                    float a = (1.0 - u) * age;                                 // how long ago the logo was here
                    float life = clamp(1.0 - 0.11 * a, 0.0, 1.0);
                    float back = (1.0 - u) * L;                               // px behind the logo
                    float k = max(0.0, 1.0 - back / 1300.0);                   // taper: widest at the logo, a thread 1300 px back
                    float shape = pow(k, 1.6);
                    float wob = sin(now * 7.0 - back / 14.0) * 22.0 * shape;
                    float along = dot(q - s, dir);
                    float over = max(along - L, 0.0) + max(-along, 0.0);          // round ends, nothing ahead of the logo
                    float d = length(vec2(dot(q - s, nrm) - wob, over));
                    float w = 1.5 + 39.0 * shape * life;                       // half width
                    float body = exp(-d * d / (w * w)) * life * pow(k, 0.7);
                    float core = exp(-d * d / (w * w * 0.06)) * life * pow(k, 0.7);
                    float swirl = 0.65 + 0.35 * sin(q.x * 0.021 + now * 3.1) * sin(q.y * 0.026 - now * 2.3 + u * 6.0);
                    vec3 col = hsv(fract(hue0 - a * 0.667)) * body * swirl * 0.9 + vec3(core * 0.55);
                    float fb = fade * bright;
                    gl_FragColor = vec4(col * fb, clamp(max(body, core) * fb, 0.0, 1.0)) * qt_Opacity;
                }"
        }
    }

    // ---------- the logo: white cut-out tinted by a tiny shader (only the letters, disc and TM) ----------
    Image { id: logoImg; source: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAATsAAACbCAYAAAAdtzydAAAWfmNhQlgAABZ+anVtYgAAAB5qdW1kYzJwYQARABCAAACqADibcQNjMnBhAAAAFlhqdW1iAAAAR2p1bWRjMm1hABEAEIAAAKoAOJtxA3VybjpjMnBhOjljOTk2NjE3LTdiZDktNGM2My05YThhLTI3M2FiNWZhMTg5NgAAAAOTanVtYgAAAClqdW1kYzJhcwARABCAAACqADibcQNjMnBhLmFzc2VydGlvbnMAAAAAuGp1bWIAAABEanVtZGNib3IAEQAQgAAAqgA4m3ETYzJwYS5pbmdyZWRpZW50LnYzAAAAABhjMnNoZ72aEKZxsmM6K65xEPHVxgAAAGxjYm9yo2lkYzpmb3JtYXRpaW1hZ2UvcG5namluc3RhbmNlSUR4LHhtcDppaWQ6ZmFlZTI0ZmYtNjYzNi00ZjlhLTg1NzEtYTQ3MmQ5YTViYmUwbHJlbGF0aW9uc2hpcGhwYXJlbnRPZgAAAeJqdW1iAAAAQWp1bWRjYm9yABEAEIAAAKoAOJtxE2MycGEuYWN0aW9ucy52MgAAAAAYYzJzaGy6ZjTLAycRyxK29792QWYAAAGZY2JvcqJnYWN0aW9uc4KiZmFjdGlvbmtjMnBhLm9wZW5lZGpwYXJhbWV0ZXJzoWtpbmdyZWRpZW50c4GiY3VybHgtc2VsZiNqdW1iZj1jMnBhLmFzc2VydGlvbnMvYzJwYS5pbmdyZWRpZW50LnYzZGhhc2hYIMzTI3k0LmB92CXbs/a/JKkdnzu78p7sduor+t2ou9l0pGZhY3Rpb254HWNvbS5hbnRocm9waWMuY2xhdWRlLnByb3ZpZGVkanBhcmFtZXRlcnOheB9jb20uYW50aHJvcGljLm9yaWdpbi1jb25maWRlbmNlZ3Vua25vd25rZGVzY3JpcHRpb254ZkNsYXVkZSBwcm92aWRlZCB0aGlzIGZpbGUgYXQgdGhlIHJlcXVlc3Qgb2YgYSB1c2VyIGFuZCBtYXkgaGF2ZSBjcmVhdGVkIG9yIG1vZGlmaWVkIHRoZSBmaWxlIGNvbnRlbnRzLm1zb2Z0d2FyZUFnZW50oWRuYW1lZkNsYXVkZXJhbGxBY3Rpb25zSW5jbHVkZWT1AAAAyGp1bWIAAABAanVtZGNib3IAEQAQgAAAqgA4m3ETYzJwYS5oYXNoLmRhdGEAAAAAGGMyc2ibbIxLSHzM/g4hYprGoBC7AAAAgGNib3KlY2FsZ2ZzaGEyNTZjcGFkTQAAAAAAAAAAAAAAAABkaGFzaFgg0MpzqWHVeFFzeF2V1ydGvequkKFih9EwneunNvH/Dy1kbmFtZW5qdW1iZiBtYW5pZmVzdGpleGNsdXNpb25zgaJlc3RhcnQYIWZsZW5ndGgZFooAAAI+anVtYgAAACdqdW1kYzJjbAARABCAAACqADibcQNjMnBhLmNsYWltLnYyAAAAAg9jYm9ypWNhbGdmc2hhMjU2aXNpZ25hdHVyZXhNc2VsZiNqdW1iZj0vYzJwYS91cm46YzJwYTo5Yzk5NjYxNy03YmQ5LTRjNjMtOWE4YS0yNzNhYjVmYTE4OTYvYzJwYS5zaWduYXR1cmVqaW5zdGFuY2VJRHgseG1wOmlpZDpjMzQ4MWFhMS1hZTZhLTRiOGMtOWVmMC02MTE3MDc5NWM3OWRyY3JlYXRlZF9hc3NlcnRpb25zg6JjdXJseC1zZWxmI2p1bWJmPWMycGEuYXNzZXJ0aW9ucy9jMnBhLmluZ3JlZGllbnQudjNkaGFzaFggzNMjeTQuYH3YJduz9r8kqR2fO7vynux26iv63ai72XSiY3VybHgqc2VsZiNqdW1iZj1jMnBhLmFzc2VydGlvbnMvYzJwYS5hY3Rpb25zLnYyZGhhc2hYIKeHssMkw4w+S5VjiT6ANtCR8K4skL+WPOIxuDF1YvnXomN1cmx4KXNlbGYjanVtYmY9YzJwYS5hc3NlcnRpb25zL2MycGEuaGFzaC5kYXRhZGhhc2hYIDW3gqVe9G14JV4MFrLagaCMZOgLz2C9H7kfYl8TX5KldGNsYWltX2dlbmVyYXRvcl9pbmZvo2RuYW1lb0FudGhyb3BpYyBGaWxlc2d2ZXJzaW9uZTEuMC4wa3NwZWNWZXJzaW9uZTIuNC4wAAAQOGp1bWIAAAAoanVtZGMyY3MAEQAQgAAAqgA4m3EDYzJwYS5zaWduYXR1cmUAAAAQCGNib3LShFkCEqIBJhghWQIKMIICBjCCAY2gAwIBAgIUQOWgCu7COdC+uIP6BkIFPWdVEwAwCgYIKoZIzj0EAwMwSTEXMBUGA1UEChMOQW50aHJvcGljLCBQQkMxLjAsBgNVBAMTJUFudGhyb3BpYyBDb250ZW50IENyZWRlbnRpYWxzIFJvb3QgQ0EwHhcNMjYwODA3MTg0MzU2WhcNMjgwODA2MTk0MzU2WjBEMRcwFQYDVQQKEw5BbnRocm9waWMsIFBCQzEpMCcGA1UEAxMgQW50aHJvcGljIENsYXVkZSBDb250ZW50IFNpZ25pbmcwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAASYegpry1AYBRTVNL1CpTlbROnY3dey+UrsF9C3phYrATN3ZHf93Mo8RQN0KOUuOn19P4oWNFWe5n2/She9N7eTo1gwVjAOBgNVHQ8BAf8EBAMCB4AwFQYDVR0lBA4wDAYKKwYBBAGD6F4CATAMBgNVHRMBAf8EAjAAMB8GA1UdIwQYMBaAFM5R4gSBTmRbI/jjxM+aPpzB11zCMAoGCCqGSM49BAMDA2cAMGQCMDFzHRSeAXrSy1WOzkbhPZ6Km2wGTmZ/2gK18k8BQGXyqz88Rdrz6CTX9flAnYNVxgIwcF9c3fVhqmJKpi+UhasNUMko69cyX6STPfta3Q8EjyzDjzoyrol46FP6VFHhvUcJoWNwYWRZDZ4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA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"; visible: false; smooth: true }
    ShaderEffect {
        x: win.bx; y: win.by; width: win.bw; height: win.bh
        property variant src: logoImg
        property color tint: win.tint
        property real bright: win.bright
        fragmentShader: "
            varying highp vec2 qt_TexCoord0;
            uniform sampler2D src; uniform lowp vec4 tint; uniform lowp float bright; uniform lowp float qt_Opacity;
            void main() { lowp float a = texture2D(src, qt_TexCoord0).a; gl_FragColor = vec4(tint.rgb * bright * a, a) * qt_Opacity; }"
    }

    // ---------- ripples: seven wide soft rainbow bands rolling out from the logo as it moves, flowing into each other ----------
    Item {
        width: 960; height: 540; scale: 2; transformOrigin: Item.TopLeft
        visible: (win.t - win.hitT) < 3600
        ShaderEffect {
            anchors.fill: parent
            property real age: (win.t - win.hitT) / 1000
            property point c: Qt.point(win.bx + win.bw / 2, win.by + win.bh / 2)   // follows the logo
            property real hue0: win.hue
            property real bright: win.bright
            fragmentShader: "
                #ifdef GL_ES
                precision mediump float;
                #endif
                varying highp vec2 qt_TexCoord0;
                uniform lowp float qt_Opacity;
                uniform float age; uniform vec2 c; uniform float hue0; uniform float bright;
                vec3 hsv(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }
                void main() {
                    float d = length(qt_TexCoord0 * vec2(1920.0, 1080.0) - c);
                    vec3 col = vec3(0.0); float al = 0.0;
                    for (int i = 0; i < 7; i++) {
                        float ti = age - float(i) * 0.16;
                        if (ti > 0.0) {
                            float life = max(0.0, 1.0 - 0.42 * ti);
                            float r = ti * 900.0;
                            float w = 110.0 + 90.0 * (1.0 - life);
                            float x = (d - r) / w;
                            float b = exp(-x * x * 2.5) * 0.9 * life;
                            col += hsv(fract(hue0 + float(i) * 0.139)) * b;
                            al = max(al, b);
                        }
                    }
                    gl_FragColor = vec4(col * bright, clamp(al * bright, 0.0, 1.0)) * qt_Opacity;
                }"
        }
    }

    // ---------- the flash ----------
    Rectangle {
        id: flash
        anchors.fill: parent
        color: "white"
        opacity: 0
        NumberAnimation on opacity { id: flashAnim; running: false; from: 0.55 * win.bright; to: 0; duration: 260; easing.type: Easing.OutQuad }
    }
}
