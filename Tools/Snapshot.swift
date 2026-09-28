// Régénère les images du README à partir de l'atelier compilé.
// Usage : snapshot <atelier.html de l'app compilée> <dossier de sortie>
//
// Produit :
//   decollage.gif  un sticker qu'on décolle par le coin jusqu'au presse-papiers
//   apercu.jpg     l'atelier entier, un coin du sticker en train de se décoller
//   planche.jpg    quelques idées de l'atelier posées sur le tapis de découpe
//
// La capture d'un WKWebView ne contient pas le rendu WebGL. Le sticker est donc dessiné
// dans la page (drawGL puis lecture du canvas dans la même tâche) et superposé à la capture.

import AppKit
import WebKit
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage : snapshot <atelier.html> <dossier>")
    exit(1)
}
let htmlURL = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2], isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let viewSize = NSSize(width: 1360, height: 860)
let fps = 15
let sheetPresets = [0, 3, 2, 5, 6, 1]   // idées de l'atelier (index dans PRESETS) posées sur la planche

// Outils injectés dans la page : ils font avancer la boucle d'animation de l'atelier image par image.
let helpers = #"""
window.__snap = {
  frames: [], kept: [],
  pause(){ this.raf = window.requestAnimationFrame; window.requestAnimationFrame = () => 0; this.t = Math.max(performance.now(), prev); },
  resume(){ window.requestAnimationFrame = this.raf; P.mode = 'idle'; P.D = 0; P.Dt = 0; P.fadeIn = 1; this.raf.call(window, frame); },
  step(ms){ this.t += ms; frame(this.t); },
  // on attrape le coin en haut à droite, puis on tire vers la gauche : le rabat reste dans la bande du sticker
  corner(){
    const c = cornerPoint();
    return { c, n: normalAt(c[0], c[1]), dir: [1, 0], w: S.die.x1 - S.die.x0 };
  },
  film(fps){
    const ms = 1000/fps, gl = document.getElementById('gl'), rect = gl.getBoundingClientRect(), k = gl.width/rect.width;
    this.pause();
    P.mode = 'idle'; P.D = 0; P.Dt = 0; P.fadeIn = 1; V.s = 1; V.vs = 0;
    for (let i = 0; i < 45; i++) this.step(ms);
    // cadre : la zone du sticker au repos, avec de la place au-dessus pour l'envol
    const q = 4, probe = document.createElement('canvas');
    probe.width = Math.ceil(gl.width/q); probe.height = Math.ceil(gl.height/q);
    const pc = probe.getContext('2d');
    pc.drawImage(gl, 0, 0, probe.width, probe.height);
    const a = pc.getImageData(0, 0, probe.width, probe.height).data;
    let x0 = Infinity, y0 = Infinity, x1 = -1, y1 = -1;
    for (let y = 0; y < probe.height; y++) for (let x = 0; x < probe.width; x++){
      if (a[(y*probe.width + x)*4 + 3] > 60){ x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
    }
    if (x1 < 0){ this.resume(); return JSON.stringify({ n: 0 }); }
    const u = q/k, bw = (x1 - x0 + 1)*u, bh = (y1 - y0 + 1)*u;
    const cx = Math.max(0, x0*u - bw*0.1), cy = Math.max(0, y0*u - bh*0.3);
    const cw = Math.min(rect.width - cx, bw*1.18), ch = Math.min(rect.height - cy, bh*1.5);
    const outW = Math.min(640, Math.round(cw)), outH = Math.round(ch*outW/cw);
    const shot = document.createElement('canvas'); shot.width = outW; shot.height = outH;
    const sc = shot.getContext('2d'); sc.imageSmoothingQuality = 'high';
    this.frames = [];
    const grab = () => { sc.clearRect(0, 0, outW, outH); sc.drawImage(gl, cx*k, cy*k, cw*k, ch*k, 0, 0, outW, outH); this.frames.push(shot.toDataURL('image/png')); };
    const run = (n, each) => { for (let i = 0; i < n; i++){ if (each) each(i, n); this.step(ms); grab(); } };
    const p = this.corner();
    run(Math.round(fps*0.7));                                                   // au repos
    P.mode = 'hover'; P.g0 = p.c; P.n0 = p.n; P.dir = p.n.slice(); P.dirT = p.n.slice(); P.Dt = 40;
    run(Math.round(fps*0.6));                                                   // le coin se soulève
    P.mode = 'drag'; P.dirT = p.dir.slice();
    run(Math.round(fps*1.1), (i, n) => { const s = (i + 1)/n; P.Dt = 40 + p.w*0.55*s*s*(3 - 2*s); });  // on tire
    P.mode = 'auto';
    for (let i = 0; i < fps*4 && P.mode !== 'gone'; i++){ this.step(ms); grab(); }   // lâché : il part
    run(Math.round(fps*1.5));                                                   // copié, un nouveau réapparaît
    this.resume();
    return JSON.stringify({ n: this.frames.length, x: rect.left + cx, y: rect.top + cy, w: cw, h: ch, outW, outH });
  },
  // pour l'aperçu, un coin corné en diagonale, comme quand on commence à tirer
  hero(){
    this.pause();
    const p = this.corner(), vx = p.n[0] + 0.6, vy = p.n[1] - 0.6, l = Math.hypot(vx, vy) || 1;
    P.mode = 'drag'; P.g0 = p.c; P.n0 = p.n; P.dir = [vx/l, vy/l]; P.dirT = P.dir.slice();
    P.Dt = 40 + p.w*0.16; P.D = P.Dt; P.fadeIn = 1; V.s = 1; V.vs = 0;
    for (let i = 0; i < 30; i++) this.step(1000/30);
    const gl = document.getElementById('gl'), r = gl.getBoundingClientRect();
    return JSON.stringify({ x: r.left, y: r.top, w: r.width, h: r.height, png: gl.toDataURL('image/png') });
  },
  keep(){
    const c = renderPng(1);
    if (!c) return 'rien';
    this.kept.push(c);
    return c.width + '×' + c.height;
  },
  sheet(){
    const L = this.kept;
    if (!L.length) return '';
    const W = 1600, pad = 64, gap = 40, cols = 2, rows = Math.ceil(L.length/cols);
    const cellW = (W - 2*pad - gap*(cols - 1))/cols, cellH = 300, H = Math.round(2*pad + rows*cellH + (rows - 1)*gap);
    const cv = document.createElement('canvas'); cv.width = W; cv.height = H;
    const g = cv.getContext('2d');
    g.fillStyle = '#1d5645'; g.fillRect(0, 0, W, H);
    const grid = (step, color) => { g.fillStyle = color; for (let x = 0; x < W; x += step) g.fillRect(x, 0, 1, H); for (let y = 0; y < H; y += step) g.fillRect(0, y, W, 1); };
    grid(20, 'rgba(206,236,219,.085)'); grid(100, 'rgba(206,236,219,.2)');
    const vg = g.createRadialGradient(W/2, H/2, Math.min(W, H)*0.3, W/2, H/2, Math.max(W, H)*0.75);
    vg.addColorStop(0, 'rgba(0,0,0,0)'); vg.addColorStop(1, 'rgba(0,0,0,.3)');
    g.fillStyle = vg; g.fillRect(0, 0, W, H);
    const tilt = [-0.035, 0.03, 0.025, -0.03, 0.02, -0.025];
    L.forEach((c, i) => {
      const s = Math.min(cellW/c.width, cellH/c.height)*0.92, w = c.width*s, h = c.height*s;
      const x = pad + (i % cols)*(cellW + gap) + cellW/2, y = pad + Math.floor(i/cols)*(cellH + gap) + cellH/2;
      g.save(); g.translate(x, y); g.rotate(tilt[i % tilt.length]);
      g.shadowColor = 'rgba(2,20,14,.55)'; g.shadowBlur = 26; g.shadowOffsetY = 12;
      g.drawImage(c, -w/2, -h/2, w, h);
      g.restore();
    });
    return cv.toDataURL('image/jpeg', 0.86);
  }
};
'ok'
"""#

func dataFromURL(_ s: String) -> Data? {
    guard let comma = s.firstIndex(of: ",") else { return nil }
    return Data(base64Encoded: String(s[s.index(after: comma)...]))
}

func object(_ result: Any?) -> [String: Any]? {
    guard let s = result as? String, let d = s.data(using: .utf8) else { return nil }
    return (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
}

func number(_ o: [String: Any], _ key: String) -> CGFloat {
    CGFloat((o[key] as? NSNumber)?.doubleValue ?? 0)
}

func frameRect(_ o: [String: Any]) -> NSRect {
    NSRect(x: number(o, "x"), y: number(o, "y"), width: number(o, "w"), height: number(o, "h"))
}

// Superpose des calques (rectangles en px CSS, origine en haut à gauche) à une zone de la capture.
func compose(_ base: NSImage, crop: NSRect, layers: [(NSImage, NSRect)], width: Int, height: Int) -> NSBitmapImageRep? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    rep.size = crop.size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    let source = NSRect(x: crop.minX, y: viewSize.height - crop.maxY, width: crop.width, height: crop.height)
    base.draw(in: NSRect(origin: .zero, size: crop.size), from: source, operation: .copy, fraction: 1)
    for (image, r) in layers {
        let target = NSRect(x: r.minX - crop.minX, y: crop.maxY - r.maxY, width: r.width, height: r.height)
        image.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writeJPEG(_ rep: NSBitmapImageRep, _ name: String) {
    if let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.86]),
       (try? data.write(to: outDir.appendingPathComponent(name))) != nil {
        print(name)
    }
}

func writeGIF(_ frames: [CGImage], _ name: String) {
    let url = outDir.appendingPathComponent(name)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else { return }
    let loop = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]]
    CGImageDestinationSetProperties(dest, loop as CFDictionary)
    for (i, image) in frames.enumerated() {
        let delay = i == frames.count - 1 ? 0.9 : 1.0/Double(fps)   // petite pause avant de recommencer
        let props = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: delay]]
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
    }
    if CGImageDestinationFinalize(dest) { print("\(name) (\(frames.count) images)") }
}

final class Shooter: NSObject, WKNavigationDelegate {
    let web: WKWebView
    let window: NSWindow
    var gifFrames: [CGImage] = []

    init(html: URL) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        web = WKWebView(frame: NSRect(origin: .zero, size: viewSize), configuration: config)
        window = NSWindow(contentRect: NSRect(x: -12000, y: -12000, width: viewSize.width, height: viewSize.height),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        super.init()
        window.contentView = web
        window.orderFrontRegardless()
        web.navigationDelegate = self
        web.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
    }

    func after(_ seconds: Double, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func js(_ source: String, _ done: @escaping (Any?) -> Void) {
        web.evaluateJavaScript(source) { result, error in
            if let error = error { print("js : \(error)") }
            done(result)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        after(4.5) { self.js(helpers) { _ in self.film() } }
    }

    // 1. Le décollage, image par image, posé sur la capture de l'atelier au repos
    func film() {
        web.takeSnapshot(with: nil) { ui, _ in
            guard let ui = ui else { print("capture impossible"); self.hero(); return }
            self.js("__snap.film(\(fps))") { result in
                guard let o = object(result), let n = o["n"] as? Int, n > 0 else {
                    print("decollage.gif ignoré : pas de sticker à l'écran")
                    self.hero()
                    return
                }
                let crop = frameRect(o), w = Int(number(o, "outW")), h = Int(number(o, "outH"))
                self.gifFrames = []
                self.fetch(0, n, ui, crop, w, h)
            }
        }
    }

    func fetch(_ i: Int, _ n: Int, _ ui: NSImage, _ crop: NSRect, _ w: Int, _ h: Int) {
        guard i < n else {
            writeGIF(gifFrames, "decollage.gif")
            hero()
            return
        }
        js("__snap.frames[\(i)]") { result in
            if let s = result as? String, let data = dataFromURL(s), let layer = NSImage(data: data),
               let rep = compose(ui, crop: crop, layers: [(layer, crop)], width: w, height: h), let image = rep.cgImage {
                self.gifFrames.append(image)
            }
            self.fetch(i + 1, n, ui, crop, w, h)
        }
    }

    // 2. L'atelier entier, un coin du sticker soulevé
    func hero() {
        js("__snap.hero()") { result in
            guard let o = object(result), let s = o["png"] as? String, let data = dataFromURL(s), let layer = NSImage(data: data) else {
                print("apercu.jpg ignoré")
                self.sheet(0)
                return
            }
            self.web.takeSnapshot(with: nil) { ui, _ in
                if let ui = ui, let rep = compose(ui, crop: NSRect(origin: .zero, size: viewSize), layers: [(layer, frameRect(o))],
                                                  width: 1600, height: Int(1600*viewSize.height/viewSize.width)) {
                    writeJPEG(rep, "apercu.jpg")
                }
                self.js("__snap.resume(); 'ok'") { _ in self.sheet(0) }
            }
        }
    }

    // 3. Une planche de stickers exportés en PNG par l'atelier
    func sheet(_ i: Int) {
        guard i < sheetPresets.count else {
            js("__snap.sheet()") { result in
                if let s = result as? String, let data = dataFromURL(s),
                   (try? data.write(to: outDir.appendingPathComponent("planche.jpg"))) != nil {
                    print("planche.jpg")
                } else {
                    print("planche.jpg ignorée")
                }
                print("terminé")
                exit(0)
            }
            return
        }
        js("document.querySelector('[data-preset=\"\(sheetPresets[i])\"]').click(); 'ok'") { _ in
            self.after(3.0) {
                self.js("__snap.keep()") { result in
                    print("idée \(sheetPresets[i]) : \(result ?? "?")")
                    self.sheet(i + 1)
                }
            }
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let shooter = Shooter(html: htmlURL)
DispatchQueue.main.asyncAfter(deadline: .now() + 150) {
    print("délai dépassé")
    exit(2)
}
app.run()
