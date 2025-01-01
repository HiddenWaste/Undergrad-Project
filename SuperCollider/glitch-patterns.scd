// glitch-patterns.scd

// Boot the server with error handling
s.waitForBoot({
    "Server booted successfully".postln;
    s.plotTree;  // Show active nodes
    s.meter;     // Show audio levels
}, onFailure: {
    "Failed to boot server".postln;
});

(
// Initialize variables
~tempo = 120/60;
~pattern = 0;
~baseFreq = 440;
~lpfCutoff = 20000;

// SynthDefs
SynthDef(\glitch1, {
    arg freq=440, amp=0.5, pan=0, atk=0.01, rel=0.1;
    var sig, env;
    env = EnvGen.kr(Env.perc(atk, rel), doneAction: 2);
    sig = SinOsc.ar(freq * LFNoise1.kr(10).range(0.99, 1.01));
    sig = sig * env * amp;
    sig = Pan2.ar(sig, pan);
    Out.ar(0, sig);
}).add;

SynthDef(\glitch2, {
    arg freq=440, amp=0.5, pan=0, atk=0.01, rel=0.3;
    var sig, env;
    env = EnvGen.kr(Env.perc(atk, rel), doneAction: 2);
    sig = Pulse.ar(freq * LFNoise0.kr(20).range(0.5, 2));
    sig = RLPF.ar(sig, freq * 2, 0.3);
    sig = sig * env * amp;
    sig = Pan2.ar(sig, pan);
    Out.ar(0, sig);
}).add;

SynthDef(\glitch3, {
    arg freq=440, amp=0.5, pan=0, atk=0.05, rel=0.2;
    var sig, env;
    env = EnvGen.kr(Env.perc(atk, rel), doneAction: 2);
    sig = WhiteNoise.ar * Pulse.ar(freq);
    sig = BPF.ar(sig, freq, 0.1);
    sig = sig * env * amp;
    sig = Pan2.ar(sig, pan);
    Out.ar(0, sig);
}).add;

// OSC Receivers
OSCdef(\tempo_control, {|msg|
    ~tempo = msg[1].linexp(0, 1, 0.5, 4);
    Pdef(\pattern1).quant = 4 * ~tempo;
    Pdef(\pattern2).quant = 4 * ~tempo;
}, '/tempo');

OSCdef(\effect_trigger, {|msg|
    var effect = msg[1];
    switch(effect,
        0, { // Blowout
            Synth(\glitch3, [
                \freq, ~baseFreq * [0.5, 1, 2, 4],
                \amp, 0.3,
                \atk, 0.05,
                \rel, 0.5
            ]);
        },
        1, { // Halftime
            ~tempo = ~tempo * 0.5;
        },
        2, { // ThereAndBack
            ~lpfCutoff = 1000;
            // Gradually restore cutoff
            Routine({
                20.do {
                    ~lpfCutoff = ~lpfCutoff * 1.2;
                    0.1.wait;
                }
            }).play;
        }
    );
}, '/effect');

OSCdef(\pattern_change, {|msg|
    ~pattern = (~pattern + 1) % 2;
    if(~pattern == 0) {
        Pdef(\pattern1).play;
        Pdef(\pattern2).stop;
    } {
        Pdef(\pattern2).play;
        Pdef(\pattern1).stop;
    };
}, '/pattern');

// Patterns
Pdef(\pattern1,
    Pbind(
        \instrument, Prand([\glitch1, \glitch2], inf),
        \dur, Pseq([0.25, 0.25, 0.5], inf) * Pfunc({ ~tempo.reciprocal }),
        \freq, Prand([~baseFreq, ~baseFreq * 1.5, ~baseFreq * 2], inf),
        \amp, 0.3,
        \pan, Pwhite(-0.8, 0.8)
    )
);

Pdef(\pattern2,
    Pbind(
        \instrument, Prand([\glitch2, \glitch3], inf),
        \dur, Pseq([0.125, 0.125, 0.25, 0.5], inf) * Pfunc({ ~tempo.reciprocal }),
        \freq, Prand([~baseFreq * 0.5, ~baseFreq, ~baseFreq * 3], inf),
        \amp, 0.25,
        \pan, Pwhite(-0.8, 0.8)
    )
);

// Start initial pattern
Pdef(\pattern1).play;
)