// spellbook.scd
s = Server.local;
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 2;

(
// Wait for all previous code to complete
s.waitForBoot({
	//Server.killAll; // Clears everything if rebooting..
    OSCdef.freeAll; // Clear any previous OSC defs to avoid duplicates

	"Booting audio synthesis server...".postln;

    // Wait for SynthDefs to be added
    Server.default.sync;
	s.meter;
	s.plotTree;

	// load Synths and Patterns
	// Load SynthDefs and Patterns
	"synthdefs.scd".standardizePath.load;
	" - SynthDefs loaded".postln;

	"patterns.scd".standardizePath.load;
	" - Patterns loaded".postln;

    // Set up OSC listener
    OSCdef(\sine_t, {|msg, time, addr, recvPort|
        // plays the established sine synthdef
		Synth(\sine, [\freq, rrand(440, 880),
			\pan, Pexprand(-0.7, 0.7),
		]);

	}, '/sine_t');


	OSCdef(\kick_test, {|msg, time, addr, recvPort|
		Synth(\kick);
	}, '/kick');

	" - OSCdefs initialized".postln;

	// Initialization Finished

    " -- SuperCollider Ready! --".postln;
});
)
