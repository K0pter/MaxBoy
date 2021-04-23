(
	print(">> Installing MaxBoy Suite from file @" + (GetDir #scripts + "\\MaxBoy\\MaxBoy_Installer.ms"))
	--Setup local path
	local ScriptName = "MaxBoy_Installer.ms"
	local FileName = getThisScriptFilename() as string
	global FilteredPath = pathConfig.removePathLeaf FileName

	print(FilteredPath)

	fn existFile fname = (getfiles fname).count != 0

	--Setup copy to path
	local mainPath = ((pathConfig.GetDir #userScripts) + ( "\\MaxBoy"))

	local c_pipeBoy = mainPath + "\\PipeBoy.ms"
	local c_toolBoy = mainPath + "\\ToolBoy.ms"
	local c_projectSettings = mainPath + "\\PipeBoy_ProjectSettings.ms"
	local c_animSetup = mainPath + "\\PipeBoy_AnimSetup.ms"
	local c_animBaker = mainPath + "\\ToolBoy_AnimBaker.ms"
	local c_updateSK = mainPath + "\\ToolBoy_UpdateRigSK.ms"
	local c_settings = mainPath + "\\PipeBoy_Settings.ini"
	local c_functions = mainPath + "\\MaxBoy_Functions.ms"

	if (isDirectoryWriteable mainPath == false) do (makeDir mainPath)

	if (existFile(c_pipeBoy) == true) do (deleteFile (c_pipeBoy))
	if (existFile(c_toolBoy) == true) do (deleteFile (c_toolBoy))
	if (existFile(c_projectSettings) == true) do (deleteFile (c_projectSettings))
	if (existFile(c_animSetup) == true) do (deleteFile (c_animSetup))
	if (existFile(c_animBaker) == true) do (deleteFile (c_animBaker))
	if (existFile(c_updateSK) == true) do (deleteFile (c_updateSK))
	if (existFile(c_functions) == true) do (deleteFile (c_functions))

	copyFile ( FilteredPath + "\\PipeBoy.ms" ) c_pipeBoy
	copyFile ( FilteredPath + "\\ToolBoy.ms" ) c_toolBoy
	copyFile ( FilteredPath + "\\PipeBoy_ProjectSettings.ms" ) c_projectSettings
	copyFile ( FilteredPath + "\\PipeBoy_AnimSetup.ms" ) c_animSetup
	copyFile ( FilteredPath + "\\ToolBoy_AnimBaker.ms" ) c_animBaker
	copyFile ( FilteredPath + "\\ToolBoy_UpdateRigSK.ms" ) c_updateSK
	copyFile ( FilteredPath + "\\MaxBoy_Functions.ms" ) c_functions

	local settingsPath = (mainPath + "\\PipeBoy_Settings.ini")
	--local settingsPath = (FilteredPath + "\\PipeBoy_Settings.ini")

	if (existFile(settingsPath) == false) then
	(
		--Only copy settings if there is no settings file
		copyFile ( FilteredPath + "\\PipeBoy_Settings.ini" ) c_settings
		print("Copied settings file to: " + c_settings)
	)
	else
	(
		print("Skipping settings file...")
	)

	print("Copied project settings file to: " + c_projectSettings)
	print("Copied AnimSetup script to: " + c_animSetup)
	print("Copied AnimBaker script to: " + c_animBaker)
	print("Copied UpdateSK script to: " + c_updateSK)
	print("Copied generic functions lib to: " + c_functions)

	print("Install complete!")

	--Run these "macro-creators" with existing scripts
	MacroScript PipeBoyTool
	category:"MaxBoy"
	internalCategory:"MaxBoyTools"
	buttonText:"PipeBoy"
	toolTip:"Pipeline tool for game asset creation"
	(
		local pbPath = (GetDir #userScripts + "\\MaxBoy\\PipeBoy.ms")
		fileIn pbPath
	)

	MacroScript ToolBoyTool
	category:"MaxBoy"
	internalCategory:"MaxBoyTools"
	buttonText:"ToolBoy"
	toolTip:"Toolbox with functions to assist content creation"
	(
		local tbPath = (GetDir #userScripts + "\\MaxBoy\\ToolBoy.ms")
		fileIn tbPath
	)

	MacroScript PipeBoyUpdate
	category:"MaxBoy"
	internalCategory:"MaxBoyTools"
	buttonText:"Update"
	toolTip:"Quick installer handle"
	(
		local inPath = (GetDir #scripts + "\\MaxBoy\\MaxBoy_Installer.ms")
		fileIn inPath
	)
)
