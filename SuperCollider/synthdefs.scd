(
SynthDef.new(\sine, {                                       // Define a new SynthDef called \sine
    arg freq = 440, amp = 0.5, dur = 0.5;                   // Default values for freq, amp, and dur
    var env, sig;                                           // Declare variables for the envelope and signal
    env = EnvGen.kr(Env.perc(0.01, 0.1), doneAction: 2);    // Create an envelope with a percussive shape
    sig = SinOsc.ar(freq) * amp * env;                      // Generate a sine wave and apply the envelope
    Out.ar([0, 1], sig);                                    // Use [0, 1] to specify stereo output
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