(
SynthDef.new(\sine, {
    arg freq = 440, amp = 0.5, dur = 0.5, pan=0, out=0;
    var env, sig;
    env = EnvGen.kr(Env.perc(0.01, 0.1), doneAction: 2);
    sig = SinOsc.ar(freq) * amp * env;
	sig = Pan2.ar(sig, pan);
    Out.ar(out, sig);
    }).add;

	SynthDef.new(\kick, {
	arg freqA=1000, freqB=50, freqC=1, freqDur1=0.01, freqDur2=0.2, freqC1=1, freqC2=(-1),
	atk=0.01, rel=1, c1=1, c2=(-12), amp=0.8, pan=0, out=0;

	var sig, env, freqSweep;

	freqSweep = Env([freqA, freqB, freqC], [freqDur1, freqDur2], [freqC1, freqC2]).ar;

	env = Env([0,1,0],[atk,rel],[c1,c2]).kr(2);

	sig = SinOsc.ar(freqSweep, pi/2);
	sig = sig * env;
	sig = Pan2.ar(sig, pan, amp);
	Out.ar(out, sig)
}).add;

SynthDef.new(\hihat, {
    |out = 0, amp = 0.5, att = 0.01, rel = 0.2, ffreq = 6000, pan = 0|
	var snd = WhiteNoise.ar(amp);
	var env = Env.perc(att, rel).kr(doneAction: 2);
	snd = HPF.ar(snd * env, ffreq);
	Out.ar(out, Pan2.ar(snd, pan));
}).add;

SynthDef(\snare, {arg out = 0, amp = 0.1, sinfreq = 180, att = 0.01, rel = 0.2, ffreq = 2000, pan = 0;
	var snd1 = WhiteNoise.ar(amp);
	var snd2 = SinOsc.ar(sinfreq,0,amp);
	var env = Env.perc(att, rel).kr(doneAction: 2);
	var mix = HPF.ar(snd1, ffreq) + snd2;
	mix = mix * env;
	Out.ar(out, Pan2.ar(mix, pan));
},
metadata: (
	credit: "Bruno Tucunduva Ruviaro",
	category: \drums,
	tags: [\percussion, \snare]
)
).add;

SynthDef(\clap, {
    arg
	//Standard Arguments
	out = 0, amp = 0.5, pan = 0, att = 0.02, rel = 0.2, curve = -4,
	//Other Controls: mix is 0 - 1, fadeTime is a fraction of noise1's length.
	mix = 0.6, fadeFreq = 4000, fadeTime = 0.52;

    var env1, env2, snd, noise1, noise2;

    // noise 1: four short repeats
    env1 = Env.new(
            levels: [0, 1, 0, 0.9, 0, 0.7, 0, 0.5, 0],
            times: [att / 20, 0.009, 0, 0.008, 0, 0.01, 0, 0.03],
            curve: [0, curve, 0, curve, 0, curve, 0, curve]
        ).kr;

    noise1 = WhiteNoise.ar(env1);
	noise1 = HPF.ar(in: noise1, freq: 600);
    noise1 = LPF.ar(
		    in: noise1,
		    freq: XLine.kr(start: 7200, end: fadeFreq, dur: fadeTime * 0.058)
	    );
    noise1 = BPF.ar(in: noise1, freq: 1620, rq: 3);

    // noise 2: one longer single burst
	env2 = Env.perc(attackTime: att, releaseTime: rel, curve: [0, curve]).kr;

    noise2 = WhiteNoise.ar(env2);
    noise2 = HPF.ar(in: noise2, freq: 1000);
    noise2 = LPF.ar(in: noise2, freq: 7600);
    noise2 = BPF.ar(in: noise2, freq: 1230, rq: 0.7);

	//Mixing
	snd = Mix.ar((mix * noise1) + ((1 - mix) * noise2));
	snd = (snd * 2).softclip;
	snd = snd * amp;

	DetectSilence.ar(in: snd, doneAction: 2);

    Out.ar(out, Pan2.ar(snd, pan));
},
metadata: (
	credit: "Nathan Ho aka Snappizz, http://sccode.org/1-523",
	category: \drums,
	tags: [\unpitched, \clap, \electronic, \percussion]
	)
).add;

	SynthDef(\bpfsaw, {
	arg atk=2, sus=0, rel=3,          // Attack, Sustain, and Release for Envelopw
	c1=1, c2=(-1),
	detune=0.2, cfhzmin=0.1, cfhzmax=0.3,
	cfmin=500, cfmax=2000, rqmin=0.1, rqmax=0.2,
	lsf=200, ldb=0,
	freq=500, cf=1500, rq=0.2,
	amp=1, out=0, pan=0;   // Baseline Amplitude, Out and Pan arguments, amp bus control

	var sig, env;

	// Envelop that crescendos and decrescendos, env arguments passed, and a curve based on c1 and c2
	env = EnvGen.kr(Env([0,1,1,0], [atk, sus, rel], [c1, 0, c2]), doneAction:2);

	sig = Saw.ar(freq * LFNoise1.kr(0.5, detune).midiratio);

	// Effects
	sig = BPF.ar(
		sig,
		{LFNoise1.kr(
			LFNoise1.kr(4).exprange(cfhzmin, cfhzmax)
		).exprange(cfmin, cfmax)}!2,
		{LFNoise1.kr(0.1).exprange(rqmin, rqmax)}!2
	);

	sig = BLowShelf.ar(sig, lsf, 0.5, ldb);
	sig = Balance2.ar(sig[0], sig[1], pan);
	sig = sig * env * amp;
	Out.ar(out, sig);
}).add;
)