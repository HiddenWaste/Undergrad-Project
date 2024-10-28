// osc_project.scd
(
// Wait for all previous code to complete
s.waitForBoot({
    "Booting server...".postln;

    // Clear any previous OSC defs to avoid duplicates
    OSCdef.freeAll;

    SynthDef.new(\sine, {                                       // Define a new SynthDef called \sine
    arg freq = 440, amp = 0.5, dur = 0.5;                   // Default values for freq, amp, and dur
    var env, sig;                                           // Declare variables for the envelope and signal
    env = EnvGen.kr(Env.perc(0.01, 0.1), doneAction: 2);    // Create an envelope with a percussive shape
    sig = SinOsc.ar(freq) * amp * env;                      // Generate a sine wave and apply the envelope
    Out.ar([0, 1], sig);                                    // Use [0, 1] to specify stereo output
    }).add;                                                 // Add the SynthDef to the server

    SynthDef.new(\saw, {
        arg freq = 440, amp = 0.5, dur = 0.5;
        var env, sig;
        env = EnvGen.kr(Env.perc(0.01, 0.1), doneAction: 2);
        sig = Saw.ar(freq) * amp * env;
        Out.ar([0, 1], sig);
        }).add;

    SynthDef.new(\pulse, {
        arg freq = 440, amp = 0.5, dur = 0.5, width = 0.5;
        var env, sig;
        env = EnvGen.kr(Env.perc(0.01, 0.1), doneAction: 2);
        sig = Pulse.ar(freq, width) * amp * env;
        Out.ar([0, 1], sig);
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

    // Wait for SynthDefs to be added
    Server.default.sync;
	s.meter;
	s.plotTree;

	// Patterns to Trigger
	~rsaw = Pbind(
	\instrument, \bpfsaw,
	\freq, Pwrand([4, 8, 12, 20], [0.4, 0.4, 0.1, 0.1], inf),
	\atk, 0.1,
	\dur, 2,
	\amp, Pexprand(0.4, 0.7, inf),
	\out, Pexprand(-0.7, 0.7, inf),
	);

	~chords = Pbind(
		\instrument, \bpfsaw,
		\dur, Pwhite(4.0,8.0,inf),
		\midinote, Pxrand([
			/*Scale.minor.degrees+60,
			Scale.minor.degrees+57,
			Scale.minor.degrees+53,
			Scale.minor.degrees+50,*/
			[23,35,54,63,64],
			[45,52,54,59,61,64],
			[28,40,47,56,59,63],
			[42,52,57,61,63],
		],inf),
		\detune, Pexprand(0.05, 0.2, inf),
		\cfmin, Pwrand([100, 300, 500], [0.6, 0.3, 0.1], inf),
		\cfmax, Pwrand([1500, 2000, 1000], [0.7, 0.2, 0.1], inf),
		\rqmin, Pexprand(0.01, 0.15, inf),
		\atk, Pwhite(2.0,2.5,inf),
		\rel, Pwhite(6.5,10.0,inf),
		\ldb, 6,
		\amp, Pexprand(0.15, 0.3, inf),
		\out, 0,
	);

    // Set up OSC listener
    OSCdef(\simpleSynthTrigger, {|msg, time, addr, recvPort|

        // OSC Def that will play either a saw, sine, or pulse wave based on the first argument

        //var synthType = msg[1]; // Get the first argument from the OSC message
		Synth(\sine, [\freq, rrand(440, 880)]);

		//~rsaw.play;

	}, '/test');

    "Project ready:".postln;
    " - SynthDef loaded".postln;
    " - OSC responder ready on /trigger".postln;
    "You can now run the Python script".postln;
});
)

// Optional: To stop the project, evaluate this block:
/*
(
OSCdef(\triggerResponder).free;
"OSC responder stopped.".postln;
)
*/