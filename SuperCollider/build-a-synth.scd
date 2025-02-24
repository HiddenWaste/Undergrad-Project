// Build a Synth Workshop!!!!


// In this script we are definining one big synth where users can
// edit as many parameters as possible to find a synth they like,
// and then be able to save it as a 'preset'


(
s.waitForBoot(
	s.meter;
	s.plotTree;
)
)

(
SynthDef(\build, {
	|out=0, pan=0,freq=440, numharm=200, amp=0.6,
	rmix=0.3, room=0.5, damp=0.4, hpf=300, lpf=2000,
	atk=0.3, rel=0.5, wave=0, filter=3, effect=0,
	pha=0|

	var sig, env;

	sig = Select.ar(wave, [
		SinOsc.ar(freq, pha),
		Saw.ar(freq),
		LFTri.ar(freq, pha),
	]);

	sig = Select.ar(filter, [
		LPF.ar(sig, lpf),
		HPF.ar(sig, hpf)
	]);

	env = EnvGen.ar(Env([0,1,0], [atk, rel]), doneAction:2);
	sig = sig * env * amp;
	sig = Pan2.ar(sig, pan);
	Out.ar(out, sig);
}).add;

)

(
a = Pbindef(\a,
	\instrument, \build,
	\wave, 0,
	\freq, Pxrand((Scale.minor.degrees+60).midicps, inf),
	\pan, Pwhite(-0.8, 0.8, inf),
)
)
a.play;
a.set(\freq, 440);[,


(
Pspawner({ |sp |
	a.play;

	4.wait;

	a.set(\wave, 1);

	4. wait;

	a.set(\wave, 2);

	4.wait;

	a.stop
}).play;
)