//----------------------------------------------------------------------------------//
//                                  COPYRIGHT                                       //
//                      © 2022 Portal 2: Multiplayer Mod                            //
//  https://github.com/Portal-2-Multiplayer-Mod/Portal-2-Multiplayer-Mod/LICENSE    //
//  In the case that this file does not exist at all or in the GitHub repository,   //
//      this project will fall under a GNU LESSER GENERAL PUBLIC LICENSE            //
//----------------------------------------------------------------------------------//

//---------------------------------------------------
//         *****!Do not edit this file!*****
//---------------------------------------------------
// Purpose: The heart of the mod's content. Runs on
// every map transition to bring about features and
//                 fixes for 3+ MP.
//---------------------------------------------------

/*
    TODO:
    - Redo the entire system for LoadMapSupportCode
        - Better to merge everything into one nut file per map, even with gamemode differences
    - Find a proper way to load speedrun mod plugin
        - We could merge it into p2mm dll (need to check with Krzy first)
*/

// In case this is the client VM...
if (!("Entities" in this)) { return }

// Make sure that the user is in multiplayer mode before initiating everything
if (!IsMultiplayer()) {
    printlP2MM("This is not a multiplayer session! Disconnecting client...")
    EntFire("p2mm_servercommand", "command", "disconnect \"You cannot play the singleplayer mode when Portal 2 is launched from the Multiplayer Mod launcher. Please unmount and launch normally to play singleplayer.\"")
    return
}

printl("\n---------------------")
printl("==== calling p2mm.nut")
printl("---------------------\n")

// We don't call this one directly from the start since
// we want to continue our logic in this file for now...
IncludeScript("multiplayermod/pluginfunctionscheck.nut")    // Make sure we know the exact status of our plugin

if (!PluginLoaded) {
    // One-off check for running p2mm on first map load
    try {
        if (HasStartedP2MM) {
            return
        }
    } catch (exception) {} // Should never have an exception, try catch is here for testing...

    if (!("HasStartedP2MM" in this)) {
        HasStartedP2MM <- true
        return
    }
}

iMaxPlayers <- (Entities.FindByClassname(null, "team_manager").entindex() - 1) // Determine what the "maxplayers" cap is

if (GetDeveloperLevelP2MM()) {
    printlP2MM("Session info...")
    printlP2MM("- Current map: " + GetMapName())
    printlP2MM("- Max players allowed on the server: " + iMaxPlayers)
    printlP2MM("- Dedicated server: " + IsDedicatedServer())
}

IncludeScript("multiplayermod/config.nut")      // Import the user configuration and preferences
IncludeScript("multiplayermod/configcheck.nut") // Make sure nothing was invalid and compensate

// There's no conceivable way to tell whether or not this is the first map load after launching a server
// So we do a dirty developer level hack to something that no one sets it to and reset it when we are done
if (GetDeveloperLevel() == 918612) {
    // Take care of anything pertaining to progress check and how our plugin did when loading
    IncludeScript("multiplayermod/firstmapload.nut")
    return
}

//-------------------------------------------------------------------------------------------

// Continue loading the P2:MM fixes, game mode, and features

IncludeScript("multiplayermod/variables.nut")
IncludeScript("multiplayermod/safeguard.nut")
IncludeScript("multiplayermod/functions.nut")
IncludeScript("multiplayermod/hooks.nut")
IncludeScript("multiplayermod/chatcommands.nut")

// Always have global root functions imported for any level
IncludeScript("multiplayermod/mapsupport/#propcreation.nut")
IncludeScript("multiplayermod/mapsupport/#rootfunctions.nut")

//---------------------------------------------------

// Print P2:MM game art in console
foreach (line in ConsoleAscii) { printl(line) }
delete ConsoleAscii

//---------------------------------------------------

// Now, manage everything the player has set in config.nut
// If the gamemode has exceptions of any kind, it will revert to standard mapsupport

// Import map support code
// Map name will be wonky if the client VM attempts to get the map name
function LoadMapSupportCode(gametype) {
    printl( "\n=============================================================")
    printlP2MM("Attempting to load " + gametype + " mapsupport code!")
    printl("=============================================================\n")

    if (gametype != "standard") {
        if (gametype == "speedrun") {
            // Quick check for the speedrun mod plugin
            if (!("smsm" in this)) {
                printlP2MM("Failed to load the VScript registers in the Speedrun Mod plugin! Reverting to standard mapsupport...")
                return LoadMapSupportCode("standard")
            }
        }
        try {
            // Import the core functions before the actual mapsupport
            IncludeScript("multiplayermod/mapsupport/" + gametype + "/#" + gametype + "functions.nut")
        } catch (exception) {
            printlP2MM("Failed to load the " + gametype + " core functions file!")
        }
    }

    try {
        IncludeScript("multiplayermod/mapsupport/" + gametype + "/" + GetMapName() + ".nut")
    } catch (exception) {
        if (gametype == "standard") {
            printlP2MM("Failed to load standard mapsupport for " + GetMapName() + "\n")
        }
        else {
            printlP2MM("Failed to load " + gametype + " mapsupport code! Reverting to standard mapsupport...")
            return LoadMapSupportCode("standard")
        }
    }
}

// Now, manage everything the player has set in config.nut
// If the gamemode has exceptions of any kind, it will revert to standard mapsupport
switch (Config_GameMode) {
    case 0: LoadMapSupportCode("standard"); break
    case 1: LoadMapSupportCode("speedrun"); break
    default:
        printlP2MM("\"Config_GameMode\" value in config.nut is invalid! Be sure it is set to an integer from 0-3. Reverting to standard mapsupport.")
        LoadMapSupportCode("standard")
        break
}

//---------------------------------------------------

// Run InstantRun() shortly AFTER spawn (hooks.nut)
EntFire("p2mm_servercommand", "command", "script InstantRun()", 0.02)
