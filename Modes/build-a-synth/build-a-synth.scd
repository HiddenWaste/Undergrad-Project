(
// Boot server and initialize
s.waitForBoot({
  // Initialize MIDI
  MIDIClient.init;
  MIDIIn.connectAll;

  // Print available MIDI devices
  "Available MIDI devices:".postln;
  MIDIClient.sources.do({ |device, i|
    ("  " ++ i ++ ": " ++ device.device ++ " - " ++ device.name).postln;
  });

  // Create OSC connection to Processing
  ~procAddr = NetAddr("127.0.0.1", 12000);

  // Basic mixer bus for analyzing all synths
  ~mixerBus = Bus.audio(s, 2);

  // Your synth definition with gate parameter and output to the mixer bus
  SynthDef(\build, {
    |freq=440, wave_choice=0, amp=0.6, out=0, pan=0, pha=0, atk=0.4, rel=0.7,
    filter_choice=0, hpf=1000, lpf=3000, bpf=1500, rq=1, rmix=0.33, room=0.5,
    damp=0.4, fx_choice_0=0, fx_choice_1=0, gate=1|
    var sig, env;

    // === Wave Selection === //
    sig = Select.ar(wave_choice, [
      SinOsc.ar(freq, pha),
      Saw.ar(freq, pha/pi),
      LFTri.ar(freq, pha/pi),
    ]);

    // ==== Filter Selection === //
    sig = Select.ar(filter_choice, [
      sig,
      RHPF.ar(sig, hpf, rq), // Resonant HPF for better sound
      RLPF.ar(sig, lpf, rq), // Resonant LPF for better sound
      BPF.ar(sig, bpf, rq),
    ]);

    // === Effect Selection === //
    sig = Select.ar(fx_choice_0, [
      sig,
      FreeVerb.ar(sig, rmix, room, damp),
      Limiter.ar(sig, amp*2),
    ]);

    sig = Select.ar(fx_choice_1, [
      sig,
      FreeVerb.ar(sig, rmix, room, damp),
      Limiter.ar(sig, amp*2),
    ]);

    // Using ADSR envelope with gate for proper note releases
    env = EnvGen.ar(Env.adsr(atk, 0.1, 0.8, rel), gate, doneAction:2);
    sig = Pan2.ar(sig, pan);
    sig = sig * env * amp;

    // Send to the mixer bus
    Out.ar(~mixerBus, sig);
  }).add;

  // Mixer that takes from the bus and sends to main output
  SynthDef(\mixer, {
    |in, out=0, volume=1|
    var sig = In.ar(in, 2) * volume;
    Out.ar(out, sig);
  }).add;

  // Completely revised spectrum analyzer for visualization
  SynthDef(\analyzer, {
    |in=0, rate=20|
    var input, fft, spectrum;

    // Get audio from the input bus
    input = In.ar(~mixerBus, 2).sum;

    // Create FFT analysis
    fft = FFT(LocalBuf(1024), input);

    // Use a better approach: send multiple frequency bands via OSC
    // 256 frequency bands (sending all 512 would be too many messages)
    256.do { |i|
      var freq = i.linexp(0, 255, 20, 20000); // Logarithmic frequency mapping
      var power = RunningSum.rms(BPF.ar(input, freq, 0.15), 20);
      var amp = power.poll(2, "power");

      // Send OSC at a reasonable rate
      SendReply.kr(
        Impulse.kr(rate), // 20 times per second
        '/spectrum',
        [i, amp], // Send index and amplitude
        i // Unique reply ID for each band
      );
    };
  }).add;

  // Wait for synths to be added
  s.sync;

  // Initialize global settings
  ~currentSettings = (
    wave: 0,
    filter: 0,
    fx0: 0,
    fx1: 0,
    amp: 0.5,
    atk: 0.4,
    rel: 0.7,
    hpf: 1000,
    lpf: 3000,
    bpf: 1500,
    rq: 1,
    rmix: 0.33,
    room: 0.5,
    damp: 0.4
  );

  // Dictionary to track active notes
  ~notes = Dictionary.new;

  // Start the mixer
  ~mixer = Synth(\mixer, [\in, ~mixerBus, \out, 0, \volume, 1]);

  // Start the analyzer
  ~analyzer = Synth(\analyzer, [\in, ~mixerBus]);

  // OSC Responder for spectrum data to forward to Processing
  // This sends each frequency bin to Processing
  OSCdef(\spectrumData, {|msg, time, addr, recvPort|
    var index = msg[3];
    var value = msg[4];

    // Forward to Processing
    ~procAddr.sendMsg("/spectrum", index, value);
  }, '/spectrum');

  // MIDI note handlers with OSC notifications
  MIDIdef.noteOn(\noteOn, {
    arg vel, note, chan, src;
    var freq = note.midicps;

    ~notes[note] = Synth(\build, [
      \freq, freq,
      \amp, vel/127 * ~currentSettings.amp,
      \wave_choice, ~currentSettings.wave,
      \filter_choice, ~currentSettings.filter,
      \fx_choice_0, ~currentSettings.fx0,
      \fx_choice_1, ~currentSettings.fx1,
      \hpf, ~currentSettings.hpf,
      \lpf, ~currentSettings.lpf,
      \bpf, ~currentSettings.bpf,
      \rq, ~currentSettings.rq,
      \rmix, ~currentSettings.rmix,
      \room, ~currentSettings.room,
      \damp, ~currentSettings.damp,
      \atk, ~currentSettings.atk,
      \rel, ~currentSettings.rel,
      \gate, 1
    ]);

    // Send note info to Processing
    ~procAddr.sendMsg("/synth/noteOn", note, vel);

    ("Note On: " ++ note ++ " Freq: " ++ freq).postln;
  });

  MIDIdef.noteOff(\noteOff, {
    arg vel, note, chan, src;

    if(~notes[note].notNil, {
      ~notes[note].set(\gate, 0);
      ~notes.removeAt(note);

      // Send note release to Processing
      ~procAddr.sendMsg("/synth/noteOff", note);

      ("Note Off: " ++ note).postln;
    });
  });

  // Parameter change functions with OSC notifications
  ~setWave = {|choice|
    choice = choice.clip(0, 2);
    ~currentSettings.wave = choice;

    // Update all active synths
    ~notes.do {|synth|
      synth.set(\wave_choice, choice);
    };

    // Send to Processing
    ~procAddr.sendMsg("/synth/wave", choice);

    ("Wave set to: " ++ ["Sine", "Saw", "Triangle"][choice]).postln;
  };

  ~setFilter = {|choice|
    choice = choice.clip(0, 3);
    ~currentSettings.filter = choice;

    // Update all active synths
    ~notes.do {|synth|
      synth.set(\filter_choice, choice);
    };

    // Send to Processing
    ~procAddr.sendMsg("/synth/filter", choice);

    ("Filter set to: " ++ ["None", "High Pass", "Low Pass", "Band Pass"][choice]).postln;
  };

  ~setFx0 = {|choice|
    choice = choice.clip(0, 2);
    ~currentSettings.fx0 = choice;

    // Update all active synths
    ~notes.do {|synth|
      synth.set(\fx_choice_0, choice);
    };

    // Send to Processing
    ~procAddr.sendMsg("/synth/fx0", choice);

    ("Effect 1 set to: " ++ ["None", "Reverb", "Limiter"][choice]).postln;
  };

  ~setFx1 = {|choice|
    choice = choice.clip(0, 2);
    ~currentSettings.fx1 = choice;

    // Update all active synths
    ~notes.do {|synth|
      synth.set(\fx_choice_1, choice);
    };

    // Send to Processing
    ~procAddr.sendMsg("/synth/fx1", choice);

    ("Effect 2 set to: " ++ ["None", "Reverb", "Limiter"][choice]).postln;
  };

  ~setAmp = {|value|
    value = value.clip(0, 1);
    ~currentSettings.amp = value;

    // Update all active synths
    ~notes.do {|synth|
      synth.set(\amp, value);
    };

    // Send to Processing
    ~procAddr.sendMsg("/synth/amp", value);

    ("Amplitude set to: " ++ value).postln;
  };

  ~setAtk = {|value|
    value = value.clip(0.01, 5);
    ~currentSettings.atk = value;

    // Update all active synths
    ~notes.do {|synth|
      synth.set(\atk, value);
    };

    // Send to Processing
    ~procAddr.sendMsg("/synth/atk", value);

    ("Attack set to: " ++ value).postln;
  };

  ~setRel = {|value|
    value = value.clip(0.01, 10);
    ~currentSettings.rel = value;

    // Update all active synths
    ~notes.do {|synth|
      synth.set(\rel, value);
    };

    // Send to Processing
    ~procAddr.sendMsg("/synth/rel", value);

    ("Release set to: " ++ value).postln;
  };

  // Setter functions for filter parameters
  ~setLpf = {|value|
    value = value.clip(20, 20000);
    ~currentSettings.lpf = value;

    // Update all active synths
    ~notes.do {|synth|
      synth.set(\lpf, value);
    };

    ("LPF cutoff set to: " ++ value).postln;
  };

  ~setHpf = {|value|
    value = value.clip(20, 20000);
    ~currentSettings.hpf = value;

    // Update all active synths
    ~notes.do {|synth|
      synth.set(\hpf, value);
    };

    ("HPF cutoff set to: " ++ value).postln;
  };

  ~setBpf = {|value|
    value = value.clip(20, 20000);
    ~currentSettings.bpf = value;

    // Update all active synths
    ~notes.do {|synth|
      synth.set(\bpf, value);
    };

    ("BPF freq set to: " ++ value).postln;
  };

  ~setRq = {|value|
    value = value.clip(0.1, 10);
    ~currentSettings.rq = value;

    // Update all active synths
    ~notes.do {|synth|
      synth.set(\rq, value);
    };

    ("Filter Q set to: " ++ value).postln;
  };

  // Load preset function
  ~loadPreset = {|preset|
    case
    {preset == 0} { // Default clean sound
      ~currentSettings.wave = 0;
      ~currentSettings.filter = 0;
      ~currentSettings.fx0 = 0;
      ~currentSettings.fx1 = 0;
      ~currentSettings.amp = 0.5;
      ~currentSettings.atk = 0.4;
      ~currentSettings.rel = 0.7;
      ~currentSettings.hpf = 1000;
      ~currentSettings.lpf = 3000;
      ~currentSettings.bpf = 1500;
      ~currentSettings.rq = 1;
      ~currentSettings.rmix = 0.33;
      ~currentSettings.room = 0.5;
      ~currentSettings.damp = 0.4;
      "Clean preset loaded".postln;
    }
    {preset == 1} { // Saw with LPF
      ~currentSettings.wave = 1;
      ~currentSettings.filter = 2;
      ~currentSettings.lpf = 1200;
      ~currentSettings.fx0 = 0;
      ~currentSettings.fx1 = 0;
      ~currentSettings.amp = 0.4;
      ~currentSettings.atk = 0.1;
      ~currentSettings.rel = 0.7;
      "Saw with LPF preset loaded".postln;
    }
    {preset == 2} { // Reverb pad
      ~currentSettings.wave = 0;
      ~currentSettings.filter = 0;
      ~currentSettings.fx0 = 1;
      ~currentSettings.rmix = 0.5;
      ~currentSettings.room = 0.8;
      ~currentSettings.damp = 0.2;
      ~currentSettings.atk = 0.8;
      ~currentSettings.rel = 2.0;
      ~currentSettings.amp = 0.4;
      "Reverb pad preset loaded".postln;
    }
    {preset == 3} { // Bass sound
      ~currentSettings.wave = 1;
      ~currentSettings.filter = 2;
      ~currentSettings.lpf = 800;
      ~currentSettings.fx0 = 2;
      ~currentSettings.fx1 = 0;
      ~currentSettings.atk = 0.05;
      ~currentSettings.rel = 0.3;
      ~currentSettings.amp = 0.6;
      "Bass sound preset loaded".postln;
    };

    // Update all active synths
    ~notes.do {|synth|
      synth.set(
        \wave_choice, ~currentSettings.wave,
        \filter_choice, ~currentSettings.filter,
        \fx_choice_0, ~currentSettings.fx0,
        \fx_choice_1, ~currentSettings.fx1,
        \atk, ~currentSettings.atk,
        \rel, ~currentSettings.rel,
        \amp, ~currentSettings.amp,
        \lpf, ~currentSettings.lpf,
        \hpf, ~currentSettings.hpf,
        \bpf, ~currentSettings.bpf,
        \rq, ~currentSettings.rq,
        \rmix, ~currentSettings.rmix,
        \room, ~currentSettings.room,
        \damp, ~currentSettings.damp
      );
    };

    // Send updated values back to Processing
    ~procAddr.sendMsg("/synth/wave", ~currentSettings.wave);
    ~procAddr.sendMsg("/synth/filter", ~currentSettings.filter);
    ~procAddr.sendMsg("/synth/fx0", ~currentSettings.fx0);
    ~procAddr.sendMsg("/synth/fx1", ~currentSettings.fx1);
    ~procAddr.sendMsg("/synth/atk", ~currentSettings.atk);
    ~procAddr.sendMsg("/synth/rel", ~currentSettings.rel);
    ~procAddr.sendMsg("/synth/amp", ~currentSettings.amp);
  };

  // Alias for loadPreset
  ~setPreset = ~loadPreset;

  // Send initial settings to Processing
  ~procAddr.sendMsg("/synth/wave", ~currentSettings.wave);
  ~procAddr.sendMsg("/synth/filter", ~currentSettings.filter);
  ~procAddr.sendMsg("/synth/fx0", ~currentSettings.fx0);
  ~procAddr.sendMsg("/synth/fx1", ~currentSettings.fx1);
  ~procAddr.sendMsg("/synth/atk", ~currentSettings.atk);
  ~procAddr.sendMsg("/synth/rel", ~currentSettings.rel);
  ~procAddr.sendMsg("/synth/amp", ~currentSettings.amp);

  // Test function
  ~playTestNote = {|note=60, dur=1|
    var synth;

    synth = Synth(\build, [
      \freq, note.midicps,
      \amp, ~currentSettings.amp,
      \wave_choice, ~currentSettings.wave,
      \filter_choice, ~currentSettings.filter,
      \fx_choice_0, ~currentSettings.fx0,
      \fx_choice_1, ~currentSettings.fx1,
      \hpf, ~currentSettings.hpf,
      \lpf, ~currentSettings.lpf,
      \bpf, ~currentSettings.bpf,
      \rq, ~currentSettings.rq,
      \rmix, ~currentSettings.rmix,
      \room, ~currentSettings.room,
      \damp, ~currentSettings.damp,
      \atk, ~currentSettings.atk,
      \rel, ~currentSettings.rel,
      \gate, 1
    ]);

    // Send note information to Processing
    ~procAddr.sendMsg("/synth/noteOn", note, 64);

    // Schedule note off
    SystemClock.sched(dur, {
      synth.set(\gate, 0);
      ~procAddr.sendMsg("/synth/noteOff", note);
      nil;
    });

    ("Test note played: " ++ note ++ " (" ++ note.midicps.round(0.01) ++ " Hz)").postln;
  };

  // Add a function to play a chord
  ~playTestChord = {|notes=#[60, 64, 67], dur=1|
    notes.do {|note|
      ~playTestNote.(note, dur);
    };

    ("Test chord played: " ++ notes).postln;
  };

  // Add a function to play an arpeggio
  ~playArpeggio = {|notes=#[60, 64, 67, 72], interval=0.25, dur=0.2|
    var count = 0;

    notes.do {|note|
      SystemClock.sched(count * interval, {
        ~playTestNote.(note, dur);
        nil;
      });
      count = count + 1;
    };

    ("Arpeggio played: " ++ notes).postln;
  };

  // Generate a noise burst for testing the spectrum analyzer
  ~generateNoise = {|dur=2|
    var synth = Synth(\build, [
      \freq, 1000,
      \wave_choice, 1, // Saw wave (rich in harmonics)
      \filter_choice, 0, // No filter
      \amp, 0.3,
      \atk, 0.01,
      \rel, 0.1,
      \gate, 1
    ]);

    // Schedule release
    SystemClock.sched(dur, {
      synth.set(\gate, 0);
      nil;
    });

    "Generated noise burst for testing analyzer".postln;
  };

  "Build-A-Synth with MIDI and OSC ready!".postln;
  "Play your MIDI keyboard and use parameter change functions:".postln;
  "~setWave.(0) : Sine wave (0-2)".postln;
  "~setFilter.(2) : Low-pass filter (0-3)".postln;
  "~setFx0.(1) : Reverb effect (0-2)".postln;
  "~setPreset.(0) : Load presets (0-3)".postln;
  "~playTestNote.(60, 1) : Play test note".postln;
  "~playTestChord.([60, 64, 67], 1) : Play test chord".postln;
  "~playArpeggio.([60, 64, 67, 72], 0.25, 0.2) : Play arpeggio".postln;
  "~generateNoise.(2) : Generate noise burst for testing".postln;

  s.meter;

  // Send a test OSC message to notify Processing that we're ready
  ~procAddr.sendMsg("/synth/ready", 1);
});
)

// Server.killAll;


// // Try different wave types
// ~setWave.(0);  // Sine wave
// ~setWave.(1);  // Saw wave
// ~setWave.(2);  // Triangle wave

// // Try different filters
// ~setFilter.(0);  // No filter
// ~setFilter.(1);  // High pass filter
// ~setFilter.(2);  // Low pass filter
// ~setFilter.(3);  // Band pass filter

// // Adjust filter parameters
// ~setLpf.(800);    // Lower cutoff for LPF
// ~setHpf.(2000);   // Higher cutoff for HPF
// ~setBpf.(1200);   // Change center frequency for BPF
// ~setRq.(0.5);     // Narrow bandwidth for BPF

// // Try different effects
// ~setFx0.(0);  // No effect for slot 1
// ~setFx0.(1);  // Reverb for slot 1
// ~setFx0.(0.6);  // Limiter for slot 1

// // Adjust envelope
// ~setAtk.(0.01);  // Fast attack
// ~setRel.(1.5);   // Long release

// // Try some presets
// ~setPreset.(0);  // Clean sound
// ~setPreset.(1);  // Saw with LPF
// ~setPreset.(2);  // Reverb pad
// ~setPreset.(3);  // Bass sound