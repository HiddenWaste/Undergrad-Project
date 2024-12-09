(
Server.killAll;
s.waitForBoot({
    // Clear any existing OSC definitions
    OSCdef.freeAll;
    s.meter;
    s.plotTree;

    // Global buses for effects and modulation
    ~masterBus = Bus.audio(s, 2);
    ~reverbBus = Bus.audio(s, 2);

    // Pattern storage
    ~patterns = Array.newClear(3);
    ~selectedPattern = 0;
    
    // Synth Parameters - stored as Events for easy modification
    ~synthParams = Array.fill(3, { 
        (
            \freq: 440,
            \amp: 0.3,
            \mod: 0.5
        )
    });

    // SynthDefs
    SynthDef(\bellSynth, {
        |out=0, freq=440, amp=0.3, mod=0.5, gate=1|
        var sig, env, modFreq;
        modFreq = freq * LFNoise2.kr(mod.linexp(0, 1, 0.1, 8)).range(0.99, 1.01);
        env = EnvGen.kr(Env.perc(0.01, 2), gate, doneAction: 2);
        sig = SinOsc.ar(modFreq) * env * amp;
        sig = Pan2.ar(sig, LFNoise2.kr(0.5));
        Out.ar(out, sig);
    }).add;

    SynthDef(\pulseSynth, {
        |out=0, freq=440, amp=0.3, mod=0.5, gate=1|
        var sig, env, width;
        width = LFNoise2.kr(mod.linexp(0, 1, 0.1, 4)).range(0.2, 0.8);
        env = EnvGen.kr(Env.perc(0.05, 1.5), gate, doneAction: 2);
        sig = Pulse.ar(freq, width) * env * amp;
        sig = RLPF.ar(sig, freq * 2, 0.3);
        sig = Pan2.ar(sig, LFNoise2.kr(0.7));
        Out.ar(out, sig);
    }).add;

    SynthDef(\padSynth, {
        |out=0, freq=440, amp=0.3, mod=0.5, gate=1|
        var sig, env, detune;
        detune = mod.linlin(0, 1, 1, 20);
        env = EnvGen.kr(Env.perc(0.1, 4), gate, doneAction: 2);
        sig = Mix.fill(3, { |i|
            SinOsc.ar(freq * (1 + (i * detune * 0.001)))
        });
        sig = LPF.ar(sig, freq * 4);
        sig = sig * env * amp;
        sig = Pan2.ar(sig, LFNoise2.kr(0.3));
        Out.ar(out, sig);
    }).add;

    SynthDef(\reverb, {
        |in, out=0, mix=0.4, room=0.6, damp=0.5|
        var sig, wet;
        sig = In.ar(in, 2);
        wet = FreeVerb2.ar(sig[0], sig[1], mix, room, damp);
        Out.ar(out, wet);
    }).add;

    s.sync;

    // Initialize reverb
    Synth(\reverb, [\in, ~reverbBus, \out, 0], addAction: \addToTail);

    // Pattern Definitions
    ~makePatterns = {
        // Bell pattern - high melodic sequence
        ~patterns[0] = Pbind(
            \instrument, \bellSynth,
            \out, ~reverbBus,
            \scale, Scale.major,
            \degree, Pseq([0, 2, 4, 7, 9, 7, 4, 2], inf),
            \octave, 6,
            \dur, 0.25,
            \amp, Pfunc { ~synthParams[0].amp * 0.4 },
            \mod, Pfunc { ~synthParams[0].mod }
        );

        // Pulse pattern - mid-range arpeggios
        ~patterns[1] = Pbind(
            \instrument, \pulseSynth,
            \out, ~reverbBus,
            \scale, Scale.major,
            \degree, Pseq([0, 3, 5, 7, 5, 3], inf),
            \octave, 5,
            \dur, 0.5,
            \amp, Pfunc { ~synthParams[1].amp * 0.3 },
            \mod, Pfunc { ~synthParams[1].mod }
        );

        // Pad pattern - slow bass movement
        ~patterns[2] = Pbind(
            \instrument, \padSynth,
            \out, ~reverbBus,
            \scale, Scale.major,
            \degree, Pseq([0, -3, -2, -4], inf),
            \octave, 4,
            \dur, 2,
            \amp, Pfunc { ~synthParams[2].amp * 0.5 },
            \mod, Pfunc { ~synthParams[2].mod }
        );
    };

    // Start all patterns
    ~startPatterns = {
        ~patterns.do { |pat, i|
            pat.play;
        };
    };

    // OSC Handlers
    OSCdef(\potControl, { |msg|
        var potNum = msg[1];
        var value = msg[2];
        
        switch(potNum,
            0, { ~synthParams[~selectedPattern].freq = value.linexp(0, 1, 200, 800) },
            1, { ~synthParams[~selectedPattern].amp = value },
            2, { ~synthParams[~selectedPattern].mod = value }
        );

        // Send visual update to Processing
        NetAddr("localhost", 12000).sendMsg(
            "/patternUpdate",
            ~selectedPattern,
            potNum,
            value
        );
    }, '/potControl');

    OSCdef(\selectPattern, { |msg|
        ~selectedPattern = msg[1];
        // Send selection update to Processing
        NetAddr("localhost", 12000).sendMsg(
            "/selectPattern",
            ~selectedPattern
        );
    }, '/selectPattern');

    // Initialize and start
    ~makePatterns.value;
    ~startPatterns.value;
});
)