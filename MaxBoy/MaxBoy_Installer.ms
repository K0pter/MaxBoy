(
	print("Installing MaxBoy Suite!")
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
	local c_settings = mainPath + "\\PipeBoy_Settings.ini"
	local c_functions = mainPath + "\\MaxBoy_Functions.ms"

	if (isDirectoryWriteable mainPath == false) do (makeDir mainPath)

	if (existFile(c_pipeBoy) == true) do (deleteFile (c_pipeBoy))
	if (existFile(c_toolBoy) == true) do (deleteFile (c_toolBoy))
	if (existFile(c_projectSettings) == true) do (deleteFile (c_projectSettings))
	if (existFile(c_functions) == true) do (deleteFile (c_functions))

	copyFile ( FilteredPath + "\\PipeBoy.ms" ) c_pipeBoy
	copyFile ( FilteredPath + "\\ToolBoy.ms" ) c_toolBoy
	copyFile ( FilteredPath + "\\PipeBoy_ProjectSettings.ms" ) c_projectSettings
	copyFile ( FilteredPath + "\\MaxBoy_Functions.ms" ) c_functions

	local settingsPath = (mainPath + "\\PipeBoy_Settings.ini")

	if (existFile(settingsPath) == false) then
	(	
		--Only copy settings if there is no settings file
		copyFile ( FilteredPath + "\\PipeBoy_Settings.ini" ) c_settings
	)
	else
	(
		print("Skipping settings file...")
	)	

	/*Disabled deletion due to debugging
	deleteFile (FilteredPath + "\\PipeBoy_Settings.ini")
	deleteFile (FilteredPath + "\\PipeBoy_ProjectSettings.ms")
	deleteFile (FilteredPath + "\\MaxBoy_Functions.ms")
	*/

	print("Copied settings file to: " + c_settings)
	print("Copied project settings script to: " + c_projectSettings)
	print("Copied functions script to: " + c_functions)

	print("Install complete!")

	--Run these "macro-creators" with existing scripts
	MacroScript PipeBoyTool
	category:"MaxBoy"
	internalCategory:"MaxBoyTools"
	buttonText:"PipeBoy"
	toolTip:"Pipeline tool for game asset creation"
	(
		local pPath = (pathConfig.GetDir #userScripts) + ( "\\MaxBoy\\PipeBoy.ms" )

		fileIn pPath
	)

	MacroScript ToolBoyTool
	category:"MaxBoy"
	internalCategory:"MaxBoyTools"
	buttonText:"ToolBoy"
	toolTip:"Toolbox with functions to assist content creation"
	(
		local pPath = (pathConfig.GetDir #userScripts) + ( "\\MaxBoy\\ToolBoy.ms" )

		fileIn pPath
	)
)