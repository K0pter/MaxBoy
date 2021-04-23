/*////////////////////////////////////////////////
PipeBoy_AnimSetup is used to set up multiple animation
segments in the main PipeBoy tool.
////////////////////////////////////////////////*/

(
--include "MaxBoy_Functions.ms"
--include "$userScripts\MaxBoy\MaxBoy_Functions.ms"

--Globals
persistent global path_settings, path_project, selectedProject
--Rollouts
global PipeBoy_AnimSetup
global rlt_addSequence
global UpdateUI
global filePath
global SequenceArray = #()

fn SequenceArrayToNames =
(
	local SequenceNames = #()

	for i = 1 to SequenceArray.count do
	(
		append SequenceNames SequenceArray[i].sequenceName
	)

	return SequenceNames
)

--local sequence struct
struct sequence
(
	sequenceName		= "null",   --string
	exportAccessory		= false, 	--booleanclass
	range_start 		= 0, 		--integer
	range_end 			= 1 		--integer
)

--Save to .boi file
fn SaveSequenceSettings  =
(
	gc()

	local sFile = undefined

	if (doesFileExist filePath == false) then
	(
		sFile = createFile filePath
		--print("Made new anim setup file!")
	)
	else
	(
		sFile = openFile filePath mode:"w"
		--print("Wrote to existing anim setup file!")
	)

	if (sFile != undefined) do
	(
		local i = 0

		for s in SequenceArray do
		(
			i += 1

			--print("Saved sequence << " + s.s_Name)

			format ("[PipSeq_" + (i as string) + "]" + "\n") to:sFile
			format (s.sequenceName as string + "\n") to:sFile
			format (s.exportAccessory as string + "\n") to:sFile
			format (s.range_start as string + "\n") to:sFile
			format (s.range_end as string + "\n") to:sFile
			format ("[PipSeq_END]\n\n") to:sFile

			--format (s as string + "\n") to:sFile
		)

		--format (SequenceArray as string) to:sFile
		--format "\n" to:sFile --New line
		close sFile

		--print("[ Saved sequence settings to file ]")
	)
)

--Load from .boi file
fn LoadAnimationSequences =
(
	gc()

	if (doesFileExist filePath == false) do
	(
		print("No file to load from @ " + ((ConvertPathToString filePath) as string))

		--Clear list so we don't get confused by last filled list
		free SequenceArray

		return()
	)

	local oFile = openFile filePath mode:"r"

	if (oFile != undefined) then
	(
		SequenceArray = #()

		local i = 0

		do
		(
			i += 1

			local checkCurrent = ("[PipSeq_" + (i as string) + "]")

			local searchResult = skipToString oFile checkCurrent

			if (searchResult != undefined) do
			(
				local skipPos = ((filePos oFile) + 2)

				--Start reading sequence data
				seek oFile skipPos

				--print("Name pos >" + (checkCurrent) + "< " + (filePos oFile as string))

				local r_name = (readLine oFile as string)

				--print("Post line read: " + filePos oFile as string)

			    --print("Bool pos >" + (checkCurrent) + "< " + (filePos oFile as string))

				local r_expa = (readValue oFile as booleanClass)

				local r_fsta = (readValue oFile as integer)

				local r_fend = (readValue oFile as integer)

				/*
				print(">" + (checkCurrent) + "< n: " + r_name)
				print(">" + (checkCurrent) + "< e: " + r_expa as string)
				print(">" + (checkCurrent) + "< rs: " + r_fsta as string)
			    print(">" + (checkCurrent) + "< re: " + r_fend as string)
				*/

				local loadSequence = Sequence sequenceName:(r_name) exportAccessory:r_expa range_start:r_fsta range_end:r_fend

				/*
				print(loadSequence.s_Name + "< n: " + loadSequence.s_Name as string)
				print(loadSequence.s_Name + "< e: " + loadSequence.s_ExportAccessory as string)
				print(loadSequence.s_Name + "< rs: " + loadSequence.s_Range_Start as string)
				print(loadSequence.s_Name + "< re: " + loadSequence.s_Range_End as string)
				*/

				append SequenceArray loadSequence

				--print("Loaded sequence >> " + loadSequence.sequenceName as string)
			)
		) while (searchResult != undefined)

		close oFile

		--print("Sequence Array >> " + SequenceArray as string)
		--print("[ Loaded sequences from file ]")
	)
	else
	(
		print("Unable to open file!")
	)
)

--Main UI window--
rollout PipeBoy_AnimSetup "Animation Setup" width:225 height:355
(
	--include "$userScripts\MaxBoy\MaxBoy_Functions.ms"
	local baseHeight = 220

	local spin_x = 32
	local spin_y = 280
	local spin_o = 24
	local spin_or = 68

	group ""
	(
		combobox ui_Sequences "Sequences" height:12

		button ui_Button_AddSequence "Add" pos:[70, baseHeight]
		button ui_Button_RemoveSequence "Remove" pos:[110, baseHeight]
		button ui_Button_SaveSettings "Save" pos:[170, baseHeight]
	)

	group "Sequence Settings"
	(
		spinner ui_Range_Start "Start :" pos:[spin_x, spin_y] width:64 height:16 range:[-10000, 10000, normTime 0] type:#integer
		spinner ui_Range_End "End :" pos:[spin_x, spin_y + spin_o] width:64 height:16 range:[-10000, 10000, normTime 1] type:#integer

		button ui_GetStart "<" pos:[spin_x + spin_or, spin_y] width:20 height:16 toolTip:"Set start frame to current frame"
		button ui_GetEnd   "<" pos:[spin_x + spin_or, spin_y + spin_o] width:20 height:16 toolTip:"Set end frame to current frame"

		button ui_GetStartRange "<<" pos:[spin_x + spin_or + 24, spin_y] width:20 height:16 toolTip:"Set start frame to current range start frame"
		button ui_GetEndRange   "<<" pos:[spin_x + spin_or + 24, spin_y + spin_o] width:20 height:16 toolTip:"Set start frame to current range end frame"

		checkbox ui_ExportAccessory "Export Accessory" pos:[16, spin_y + spin_o + 24] tooltip:"Export accessory animation for this sequence"

		--dropdownlist ui_Engine "Engine" items:#("Unity", "Unreal Engine 4") width:125
		--edittext ui_projectRoot "Project path:" text:("D:\\Unity\\Your\\ProjectRoot\\") width: 275 align:#left tooltip:"Path to project's root directory"
		--edittext ui_projectSource "Project Source:" text:("D:\\Unity\\Your\\ProjectSource\\") width: 275 align:#left tooltip:"Path to project's 'source/ raw' directory"
		--edittext ui_projectAsset "Asset folder:" text:("") width: 275 align:#left tooltip:"Extra path directory for asset folder"
		--checkbox ui_ImportFromRaw "Import from source setup" tooltip:"Whether or not to export to external source location or to mirrored project folder."
	)

	fn TryUpdateUI =
	(
		--Update sequence list
		if (SequenceArray.count >= 1) then
		(
			local SequenceNames = SequenceArrayToNames()
			ui_Sequences.items = SequenceNames
		)
		else
		(
			local newSequence = Sequence sequenceName:"Null" exportAccessory:false range_start:0 range_end:0

			SequenceArray = #(newSequence)

			ui_Sequences.items = #(newSequence.sequenceName as string)
		)

		--Update relative parameters
		if (ui_Sequences.selection != 0 AND ui_Sequences.selection <= SequenceArray.count) do
		(
			ui_ExportAccessory.state = SequenceArray[ui_Sequences.selection].exportAccessory
			ui_Range_Start.value = SequenceArray[ui_Sequences.selection].range_start
			ui_Range_End.value = SequenceArray[ui_Sequences.selection].range_end
		)

		--Try updating UI in PipeBoy
		try(cbf_updateui_fn())catch()
		--cbf_updateui()
	)

	on PipeBoy_AnimSetup open do
	(
		--print ("Doing opening actions!")
		local scrName = ("PipeBoy_AnimSetup")

		--local srcLocation = GetScriptLocation (getThisScriptFilename() as string) scrName
		local srcLocation = (GetDir #userScripts + "\\MaxBoy\\AnimSetup\\")

		path_settings = srcLocation

		--Create animsetup folder if it doesn't exist
		if (doesFileExist (srcLocation) == false) do (makeDir (srcLocation))

		if (maxFileName != "") then
		(
			--local filteredName = replace (maxFileName as string) (maxFileName.count - 3) 4 ""
			local filteredName = (filterString (maxFileName as string) ".")[1]

			local relativePath = (srcLocation + filteredName + ".boi")
			filePath = ConvertToPath relativePath

			--Load in data
			LoadAnimationSequences()
		)
		else
		(
			messageBox "Unsaved file! Any parameters changed would be discarded!" title:"Error"
			print("Unsaved file, any parameters changed would be discarded!")

			--Quit out of setup
			destroyDialog PipeBoy_AnimSetup
		)

		--Update UI
		TryUpdateUI()
	)

	on ui_Button_AddSequence pressed do
	(
		createDialog rlt_addSequence
	)

	on ui_Button_RemoveSequence pressed do
	(
		if (queryBox "Remove sequence?" title:"Remove" == true) do
		(
			--Delete in local array
			deleteItem SequenceArray ui_Sequences.selection

			--Store removal change
			SaveSequenceSettings()

			--Update UI
			TryUpdateUI()
		)
	)

	on ui_Button_SaveSettings pressed do
	(
		--Save settings to ".ini" file
		SaveSequenceSettings()
	)

	on ui_Sequences entered newName do
	(
		ui_Sequences.selected = newName
		SequenceArray[ui_Sequences.selection].sequenceName = newName

		SaveSequenceSettings()
	)

	on ui_Sequences selected newSelection do
	(
		TryUpdateUI()
	)

	on ui_Range_Start changed val do
	(
		SequenceArray[ui_Sequences.selection].range_start = ui_Range_Start.value

		SaveSequenceSettings()

		TryUpdateUI()
	)

	on ui_Range_End changed val do
	(
		SequenceArray[ui_Sequences.selection].range_end = ui_Range_End.value

		SaveSequenceSettings()

		TryUpdateUI()
	)

	on ui_ExportAccessory changed nState do
	(
		SequenceArray[ui_Sequences.selection].exportAccessory = nState

		SaveSequenceSettings()

		TryUpdateUI()
	)


	--[Actions for range UI]--
	on ui_GetStart pressed do
	(
		ui_Range_Start.value = sliderTime
		SequenceArray[ui_Sequences.selection].range_start = sliderTime

		SaveSequenceSettings()

		TryUpdateUI()
	)

	on ui_GetStartRange pressed do
	(
		local f = ( normTime 0 as integer ) / ticksperframe

		ui_Range_Start.value = f
		SequenceArray[ui_Sequences.selection].range_start = f

		SaveSequenceSettings()

		TryUpdateUI()
	)

	on ui_GetEnd pressed do
	(
		ui_Range_End.value = ( sliderTime )
		SequenceArray[ui_Sequences.selection].range_end = sliderTime

		SaveSequenceSettings()

		TryUpdateUI()
	)

	on ui_GetEndRange pressed do
	(
		local f = ( normTime 1 as integer ) / ticksperframe

		ui_Range_End.value = f
		SequenceArray[ui_Sequences.selection].range_end = f

		SaveSequenceSettings()

		TryUpdateUI()
	)
)

rollout rlt_addSequence "Add Sequence" width:360 height:60
(
	edittext sequence_name "Sequence name:" text:"" fieldWidth:250 labelOnTop:true
	button okButton "Add" pos:[268,21]
	button cancelButton "Cancel" pos:[305,21]

	on rlt_addSequence open do
	(
		if (maxFileName != "") do
		(
			local tempNameText = replace (maxFileName as string) (maxFileName.count - 3) 4 ""

			sequence_name.text = tempNameText
		)
	)

	on okButton pressed do
	(
		if (sequence_name.text != "") then
		(
			local newSequence = Sequence sequenceName:(sequence_name.text) exportAccessory:false range_start:0 range_end:100

			append SequenceArray newSequence

			local SequenceNames = SequenceArrayToNames()

			PipeBoy_AnimSetup.ui_Sequences.items = SequenceNames
			PipeBoy_AnimSetup.ui_Sequences.selection = SequenceArray.count

			SaveSequenceSettings()

			destroyDialog rlt_addSequence
		)
		else
		(
			messageBox "Enter a name" title:"Don't forget to enter a name!"
		)

		PipeBoy_AnimSetup.TryUpdateUI()
	)

	on cancelButton pressed do
	(
		destroyDialog rlt_addSequence
	)
)

--createDialog PipeBoy_AnimSetup pos:[1100,500]
--clearListener()
)
