// osc_project.scd
(
// Wait for all previous code to complete
s.waitForBoot({
    "Booting server...".postln;

    // Clear any previous OSC defs to avoid duplicates
    OSCdef.freeAll;

    // Wait for SynthDefs to be added
    Server.default.sync;
	s.meter;
	//s.plotTree;

	// load Synths and Patterns
	// Load SynthDefs and Patterns
    (thisProcess.nowExecutingPath.dirname +/+ "synthdefs.scd").load;
    (thisProcess.nowExecutingPath.dirname +/+ "patterns.scd").load;

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

OSCdef(\kick_test, {|msg, time, addr, recvPort|

		Synth(\kick);

	}, '/kick');

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
