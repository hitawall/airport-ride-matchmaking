// Reads the barcode on a boarding pass the rider picks from their device (a PDF
// from the airline's email, or a screenshot or photo). It runs entirely in the
// browser: the file is never uploaded anywhere.
//
// The two libraries below are only downloaded the first time someone uses this,
// from a CDN, at fixed versions (the same approach the camera scanner uses for
// its barcode library). The app turns the text this returns into a flight
// number and date, and shows it for the rider to confirm.
(function () {
  var PDFJS_BASE = "https://cdn.jsdelivr.net/npm/pdfjs-dist@6.5.438/build/";
  var ZXING_URL = "https://cdn.jsdelivr.net/npm/zxing-wasm@3.1.7/dist/es/reader/index.js";
  var MAX_PAGES = 3;
  var MAX_SIDE = 3200; // keep big photos from exhausting memory

  var libs = null;
  function load() {
    if (!libs) {
      libs = Promise.all([import(PDFJS_BASE + "pdf.min.mjs"), import(ZXING_URL)]).then(function (m) {
        m[0].GlobalWorkerOptions.workerSrc = PDFJS_BASE + "pdf.worker.min.mjs";
        return { pdfjs: m[0], zxing: m[1] };
      });
      libs.catch(function () { libs = null; }); // allow a retry after a network failure
    }
    return libs;
  }

  function pickFile() {
    return new Promise(function (resolve) {
      var input = document.createElement("input");
      input.type = "file";
      input.accept = "application/pdf,image/*";
      input.style.display = "none";
      input.addEventListener("change", function () {
        resolve(input.files && input.files[0] ? input.files[0] : null);
        input.remove();
      });
      input.addEventListener("cancel", function () {
        resolve(null);
        input.remove();
      });
      document.body.appendChild(input);
      input.click();
    });
  }

  function toImageData(source, width, height) {
    var scale = Math.min(1, MAX_SIDE / Math.max(width, height));
    var canvas = document.createElement("canvas");
    canvas.width = Math.max(1, Math.round(width * scale));
    canvas.height = Math.max(1, Math.round(height * scale));
    var ctx = canvas.getContext("2d", { willReadFrequently: true });
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(source, 0, 0, canvas.width, canvas.height);
    return ctx.getImageData(0, 0, canvas.width, canvas.height);
  }

  async function readImage(zxing, imageData) {
    var found = await zxing.readBarcodes(imageData, {
      formats: ["Aztec", "PDF417", "QRCode"],
      tryHarder: true,
      maxNumberOfSymbols: 4,
    });
    return found.map(function (b) { return b.text; }).filter(Boolean);
  }

  async function decodeFile(file) {
    var l = await load();
    var texts = [];
    if (file.type === "application/pdf" || /\.pdf$/i.test(file.name)) {
      var data = new Uint8Array(await file.arrayBuffer());
      var doc = await l.pdfjs.getDocument({ data: data }).promise;
      for (var p = 1; p <= Math.min(doc.numPages, MAX_PAGES); p++) {
        var page = await doc.getPage(p);
        // Several sizes: a small barcode needs more pixels to be read reliably.
        for (var scale of [2, 3, 4]) {
          var vp = page.getViewport({ scale: scale });
          var canvas = document.createElement("canvas");
          canvas.width = Math.ceil(vp.width);
          canvas.height = Math.ceil(vp.height);
          // intent "print" renders without waiting for animation frames, so it also
          // works when the tab is in the background.
          await page.render({ canvas: canvas, canvasContext: canvas.getContext("2d", { willReadFrequently: true }), viewport: vp, intent: "print" }).promise;
          var img = canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height);
          texts = texts.concat(await readImage(l.zxing, img));
          if (texts.length) return texts;
        }
      }
    } else {
      var bitmap = await createImageBitmap(file);
      texts = await readImage(l.zxing, toImageData(bitmap, bitmap.width, bitmap.height));
    }
    return texts;
  }

  // Resolves to a JSON string: {"cancelled":true}, {"texts":[...]} or {"error":"..."}.
  async function pickAndRead() {
    try {
      var file = await pickFile();
      if (!file) return JSON.stringify({ cancelled: true });
      return JSON.stringify({ texts: await decodeFile(file) });
    } catch (e) {
      return JSON.stringify({ error: String((e && e.message) || e) });
    }
  }

  window.airpoolPass = { pickAndRead: pickAndRead, decodeFile: decodeFile };
})();
