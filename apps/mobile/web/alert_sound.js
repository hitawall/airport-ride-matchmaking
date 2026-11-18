// A soft two-note chime for new notifications, made with Web Audio so no sound
// file is needed. Browsers only allow audio after the person has tapped or
// clicked the page once, which has always happened by the time a match arrives.
(function () {
  var ctx;
  function note(freq, start) {
    var osc = ctx.createOscillator();
    var gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.value = freq;
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.exponentialRampToValueAtTime(0.25, start + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.4);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(start);
    osc.stop(start + 0.45);
  }
  window.airpoolSound = {
    play: function () {
      try {
        var Ctx = window.AudioContext || window.webkitAudioContext;
        if (!Ctx) return;
        ctx = ctx || new Ctx();
        if (ctx.state === "suspended") ctx.resume();
        var t = ctx.currentTime;
        note(880, t);
        note(1175, t + 0.15);
      } catch (e) {
        // stay quiet
      }
    },
  };
})();
