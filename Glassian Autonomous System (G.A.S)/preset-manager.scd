// preset-manager.scd
// Helper functions for saving and loading presets

(
// Load system parameters first if not already loaded
(thisProcess.nowExecutingPath.dirname +/+ "system-information.scd").loadPaths;

// Save current settings to a file
~savePresetToFile = { |presetName, filePath|
    var preset, file;

    // Create preset from current settings
    preset = (
        tempo: ~systemParams.timing.tempo,
        process: (
            additiveDuration: ~systemParams.process.additiveDuration,
            subtractiveDuration: ~systemParams.process.subtractiveDuration
        ),
        musical: (
            initialRoot: ~musicalState.root,
            initialScale: ~musicalState.scale,
            tensionThreshold: ~systemParams.musical.tensionThreshold
        ),
        reverb: (
            roomSize: ~systemParams.reverb.roomSize,
            dampening: ~systemParams.reverb.dampening,
            mix: ~systemParams.reverb.mix
        ),
        patternRelationships: (
            influenceStrength: ~systemParams.patternRelationships.influenceStrength
        )
    );

    // Default file path in the current directory if not specified
    if(filePath.isNil) {
        filePath = thisProcess.nowExecutingPath.dirname +/+ "presets" +/+ (presetName ++ ".scd");
    };

    // Ensure presets directory exists
    if(File.exists(thisProcess.nowExecutingPath.dirname +/+ "presets").not) {
        File.mkdir(thisProcess.nowExecutingPath.dirname +/+ "presets");
    };

    // Format the preset as SuperCollider code
    var presetString = "// % preset for Glass-inspired system\n".format(presetName);
    presetString = presetString ++ "(\n";
    presetString = presetString ++ "tempo: %,\n".format(preset.tempo);

    // Process settings
    presetString = presetString ++ "process: (\n";
    presetString = presetString ++ "    additiveDuration: %,\n".format(preset.process.additiveDuration);
    presetString = presetString ++ "    subtractiveDuration: %,\n".format(preset.process.subtractiveDuration);
    presetString = presetString ++ "),\n";

    // Musical settings
    presetString = presetString ++ "musical: (\n";
    presetString = presetString ++ "    initialRoot: %,\n".format(preset.musical.initialRoot);
    presetString = presetString ++ "    initialScale: \\%,\n".format(preset.musical.initialScale);
    presetString = presetString ++ "    tensionThreshold: %,\n".format(preset.musical.tensionThreshold);
    presetString = presetString ++ "),\n";

    // Reverb settings
    presetString = presetString ++ "reverb: (\n";
    presetString = presetString ++ "    roomSize: %,\n".format(preset.reverb.roomSize);
    presetString = presetString ++ "    dampening: %,\n".format(preset.reverb.dampening);
    presetString = presetString ++ "    mix: %,\n".format(preset.reverb.mix);
    presetString = presetString ++ "),\n";

    // Pattern relationships
    presetString = presetString ++ "patternRelationships: (\n";
    presetString = presetString ++ "    influenceStrength: %,\n".format(preset.patternRelationships.influenceStrength);
    presetString = presetString ++ ")\n";
    presetString = presetString ++ ")\n";

    // Save to file
    file = File(filePath, "w");
    if(file.isOpen) {
        file.write(presetString);
        file.close;
        "Preset '%' saved to %".format(presetName, filePath).postln;
    } {
        "Failed to save preset to %".format(filePath).error;
    };
};

// Load a preset from a file
~loadPresetFromFile = { |filePath|
    var preset, presetName;

    if(File.exists(filePath)) {
        // Extract preset name from file name
        presetName = PathName(filePath).fileNameWithoutExtension;

        // Execute the file to get the preset object
        preset = filePath.load;

        if(preset.notNil) {
            // Store preset in system parameters
            ~systemParams.presets[presetName.asSymbol] = preset;

            // Load it
            ~loadPreset.value(presetName);

            "Preset '%' loaded from file".format(presetName).postln;
        } {
            "Failed to parse preset file %".format(filePath).error;
        };
    } {
        "Preset file % does not exist".format(filePath).error;
    };
};

// List all available presets (both built-in and from files)
~listPresets = {
    var builtInPresets = ~systemParams.presets.keys.asArray.sort;
    var presetDir = thisProcess.nowExecutingPath.dirname +/+ "presets";
    var filePresets = [];

    // Get presets from files
    if(File.exists(presetDir)) {
        filePresets = PathName(presetDir).files.collect({ |path|
            path.fileNameWithoutExtension.asSymbol;
        }).sort;
    };

    // Combine and deduplicate
    var allPresets = (builtInPresets ++ filePresets).asSet.asArray.sort;

    "Available presets:".postln;
    allPresets.do({ |name|
        var source = if(builtInPresets.includes(name), {
            "built-in"
        }, {
            "file"
        });

        "  % (%)".format(name, source).postln;
    });
};

// Create a batch of randomized presets for experimentation
~generateRandomPresets = { |numPresets=5|
    numPresets.do({ |i|
        var presetName = "random%".format(i + 1);
        var preset = (
            tempo: rrand(90, 140),
            process: (
                additiveDuration: [64, 96, 128, 160].choose,
                subtractiveDuration: [48, 64, 96, 112].choose
            ),
            musical: (
                initialRoot: rrand(60, 72),
                initialScale: [\minorPent, \naturalMinor, \dorian].choose,
                tensionThreshold: rrand(65, 85)
            ),
            reverb: (
                roomSize: rrand(0.4, 0.8),
                dampening: rrand(0.3, 0.7),
                mix: rrand(0.3, 0.6)
            ),
            patternRelationships: (
                influenceStrength: rrand(0.2, 0.5)
            )
        );

        // Store in system parameters
        ~systemParams.presets[presetName.asSymbol] = preset;

        "Random preset '%' generated".format(presetName).postln;
    });

    "Generated % random presets. Use ~listPresets.value() to see all available presets.".format(numPresets).postln;
};

"Preset manager loaded successfully.".postln;
"Use ~savePresetToFile.(presetName) to save current settings".postln;
"Use ~loadPresetFromFile.(filePath) to load a preset from file".postln;
"Use ~listPresets.value() to see all available presets".postln;
"Use ~generateRandomPresets.(numPresets) to create random presets".postln;
)