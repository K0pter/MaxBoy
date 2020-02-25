/*////////////////////////////////////////////////
PipeBoy is a pipeline tool that strives to improve
general workflows for game-related asset creation.
////////////////////////////////////////////////*/

--Start PipeBoy--
(
--include "MaxBoy_Functions.ms"
include "$userScripts\MaxBoy\MaxBoy_Functions.ms"

--Initialize persistent globals
persistent global currentProjectSelected, currentAssetSelected, PrintToConsole --Persistent handles

--Initialize globals
global PipeBoy --Rollout class handle
global PipeBoySettings --Pipeboy settings file
global PipeBoyAnimSetup --Pipeboy animation setup file
global PBS --Pipeboy settings .ini file handle

global UnlinkFromParent
global ZeroPivotToOrigin

global gName = (getFilenameFile  maxFileName)
global exportGroup = #()
global cleanGroup = #()
global projectArray = #()
global SequenceArray = #()

--Local settings struct
struct LocalSettings
(
	p_projectRoot, 		--String
	p_projectSource, 	--String
	p_projectAsset, 	--String

	s_Engine, 			--Integer
	s_ImportFromRaw, 	--booleanClass
	s_ForwardAxis, 		--Integer
	s_MeshGroupPrefix, 	--String

	s_BonePrefix, 		--String
	s_BoneRoot, 		--String
	s_AlignPrefix, 		--String

	s_ac_Folder,		--String
	s_ac_Prefix, 		--String
	s_ac_FindIntelligent,--booleanClass
	s_ac_LockRoot, 		--booleanClass
	s_ac_FilePrefix,	--String
	s_ac_FileSuffix,	--String
	s_ac_RemoveFilePre,	--Integer
	s_ac_RemoveFileSuf  --Integer
)

--Local sequence struct
struct Sequence
(
	s_Name 				= "Null",   --String
	s_ExportAccessory	= false, 	--booleanClass
	s_Range_Start 		= 0, 		--Integer
	s_Range_End 		= 1 		--Integer
)

--Initialize local settings "container" to easily store and update for later
global LS = LocalSettings()

fn FreezeTransforms obj =
(
  local curObj = obj

  if classOf curObj.rotation.controller != Rotation_Layer do
  (
    -- Freeze rotation
    curObj.rotation.controller = Euler_Xyz()
    curObj.rotation.controller = Rotation_List()
    curObj.rotation.controller.available.controller = Euler_Xyz()

    -- Rename rotation controllers
    curObj.rotation.controller.SetName 1 "Frozen Rotation"
    curObj.rotation.controller.SetName 2 "Zero Euler XYZ"

    -- Set the new rotation controller as the active controller
    curObj.rotation.controller.SetActive 2
  )

  if classOf curObj.position.controller != Position_Layer do
  (
    -- Freeze position
    curObj.position.controller = Bezier_Position()
    curObj.position.controller = Position_List()
    curObj.position.controller.available.controller = Position_XYZ()

    -- Rename rotation controllers
    curObj.position.controller.SetName 1 "Frozen Position"
    curObj.position.controller.SetName 2 "Zero Pos XYZ"

    -- Set the new position controller as the active controller actual
    curObj.position.controller.SetActive 2

    -- Reset the position of the actual position controller to zero
    curObj.position.controller[2].x_Position = 0
    curObj.position.controller[2].y_Position = 0
    curObj.position.controller[2].z_Position = 0
  )
)

fn FilterForMeshes &FilterArray =
(
	local TempFilterArray = #()

	for i = 1 to FilterArray.count do
	(
		--if (ClassOf FilterArray[i] == Editable_Poly OR ClassOf FilterArray[i] == Editable_Mesh) do
		if (superclassof FilterArray[i] == GeometryClass) do
		(
			append TempFilterArray FilterArray[i]
		)
	)

	return TempFilterArray
)

fn LodGenerator &Obj Lods =
(
	clearSelection()
	disableSceneRedraw()

	try
	(
	with undo off
	(
		for lodObj in Obj do
		(
			try
			(
				local removeObjFromExport = findItem exportGroup lodObj
				deleteItem exportGroup removeObjFromExport
			)
			catch
			(
				print("Couldn't delete object from export group!")
			)

			maxOps.cloneNodes lodObj cloneType:#copy newNodes:&SafeLodCopy
			append cleanGroup SafeLodCopy
			tempLodObj = SafeLodCopy[1]
			tempLodObj.name = ((TrimRight lodObj.name "0123456789") + "_LOD0")

			append exportGroup tempLodObj

			for i = 1 to Lods do
			(
				maxOps.cloneNodes tempLodObj cloneType:#copy newNodes:&SafeLodStepCopy
				append cleanGroup SafeLodStepCopy
				LodStepObject = SafeLodStepCopy[1]
				LodStepObject.name = ((TrimRight tempLodObj.name "0123456789") +  i as string)

				Optimizer = ProOptimizer OptimizationMode:1

				Optimizer.VertexPercent = (75 / i)
				Optimizer.KeepUV = true
				Optimizer.LockUV = true

				Optimizer.KeepNormals = true
				Optimizer.KeepVC = true

				Optimizer.MergePoints = true
				Optimizer.MergePointsThreshold = 5

				addmodifier LodStepObject Optimizer

				clearSelection()
				select LodStepObject

				$.modifiers[#ProOptimizer].Calculate = true
				CollapseStack LodStepObject
				ConvertTo LodStepObject Editable_Poly

				--LodStepObject.position.y += (250 * i)

				append exportGroup LodStepObject

				--free LodStepObject
			)

			--free tempLodObj
		)
	)
	)
	catch(enableSceneRedraw())

	enableSceneRedraw()
	clearSelection()
)

--Load from .boi file
fn LoadSequences =
(
	--Call garbage collection to avoid I/O issues
	--gc()
	--print(getThisScriptFilename())

	--Remove file name's extension
	local filteredName = replace (maxFileName as string) (maxFileName.count - 3) 4 ""

	--Construct search path
	local relativePath = ((getScriptLocation (getThisScriptFilename() as string) "PipeBoy") + "\\AnimSetup\\" + filteredName + ".boi")

	--print("Relative: " + relativePath)

	--Convert to valid search path
	local filePath = convertToPath relativePath

	--print("File: " + filePath)

	if (doesFileExist filePath == false) do
	(
		print("No file to load from @ " + (filePath as string))
		return()
	)

	local oFile = openFile filePath mode:"r"

	if (oFile != undefined) then
	(
		--print("Loading sequences from >> " + relativePath)

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

				local loadSequence = Sequence s_Name:(r_name) s_ExportAccessory:r_expa s_Range_Start:r_fsta s_Range_End:r_fend

				/*
				print(loadSequence.s_Name + "< n: " + loadSequence.s_Name as string)
				print(loadSequence.s_Name + "< e: " + loadSequence.s_ExportAccessory as string)
				print(loadSequence.s_Name + "< rs: " + loadSequence.s_Range_Start as string)
				print(loadSequence.s_Name + "< re: " + loadSequence.s_Range_End as string)
				*/

				append SequenceArray loadSequence

				--print("Loaded sequence >> " + loadSequence.s_Name as string)
			)
		) while (searchResult != undefined)

		close oFile

		--print("Sequence Array >> " + SequenceArray as string)
		print("[ Loaded sequences from file ]")
	)
	else
	(
		print("Couldn't find file to open!")
	)
)

rollout PipeBoy "PipeBoy"
(
	--Construct Base UI "Frame" for rollout windows
	subRollout UI_Base width:235 height:90 pos:[-1,-1]

	--Window resize function for rollouts [ Override ]
	fn resizeWindow tTarget tRollout tState =
	(
	    if (tState == true) then
	    (
			UI_Base.height += tRollout.height
			tTarget.height += tRollout.height
	    )
	    else
	    (
			UI_Base.height -= tRollout.height
			tTarget.height -= tRollout.height
	    )
	)

	fn RefreshRollouts =
	(
		global ro_m = PipeBoy.UI_RolloutGroup_Main
		global ro_a = PipeBoy.UI_RolloutGroup_Asset
		global ro_g = PipeBoy.UI_RolloutGroup_General
		global ro_p = PipeBoy.UI_RolloutGroup_Project
	)

	fn LoadVariables =
	(
		--Setup which project to load from file
		--print("PBS: " + PBS)
		tempProjectArray = getINISetting PBS "MainData" "g_Projects"
		global projectArray = execute tempProjectArray

		if (currentProjectSelected == undefined OR currentProjectSelected == 0) then
			t_selectProject = 1
			else
			t_selectProject = currentProjectSelected

		global currentProjectSelected = t_selectProject

		if (projectArray[t_selectProject] != undefined) then
		(
			local pro = (projectArray[t_selectProject] as string)

			global p_ProjectRoot 		= (getINISetting PBS pro "p_projectRoot")
			global p_ProjectSource 		= (getINISetting PBS pro "p_projectSource")
			global p_projectAsset 		= (getINISetting PBS pro "p_projectAsset")

			global s_Engine 			= (getINISetting PBS pro "s_Engine") as Integer
			global s_ImportFromRaw 		= (getINISetting PBS pro "s_ImportFromRaw") as booleanClass
			global s_ForwardAxis 		= (getINISetting PBS pro "s_ForwardAxis") as Integer
			global s_MeshGroupPrefix 	= (getINISetting PBS pro "s_MeshGroupPrefix")

			global s_BonePrefix 		= (getINISetting PBS pro "s_BonePrefix")
			global s_BoneRoot 			= (getINISetting PBS pro "s_BoneRoot")
			global s_AlignPrefix 		= (getINISetting PBS pro "s_AlignPrefix")

			global s_ac_Folder 			= (getINISetting PBS pro "s_ac_Folder")
			global s_ac_Prefix 			= (getINISetting PBS pro "s_ac_Prefix")
			global s_ac_FindIntelligent = (getINISetting PBS pro "s_ac_FindIntelligent") as booleanClass
			global s_ac_LockRoot		= (getINISetting PBS pro "s_ac_LockRoot") as booleanClass
			global s_ac_FilePrefix 		= (getINISetting PBS pro "s_ac_FilePrefix")
			global s_ac_FileSuffix 		= (getINISetting PBS pro "s_ac_FileSuffix")
			global s_ac_RemoveFilePre 	= (getINISetting PBS pro "s_ac_RemoveFilePre") as Integer
			global s_ac_RemoveFileSuf 	= (getINISetting PBS pro "s_ac_RemoveFileSuf") as Integer

			print("Loaded project: " + pro)
		)
		else
		(
			MessageBox "Project seems to be missing!" title:"Missing project!"
		)
	)

	fn RotatePivotOnlyEngine obj =
	(
		/*
		1 = X-Forward
		2 = - X-Forward
		3 = Y-Forward
		4 = - Y-Forward
		*/

		local RotValInv --Set up local rotation variable

		case s_Engine of
		(
			--local rotValInv = case s_ForwardAxis of

			1:
			(
				RotValInv = EulerAngles 90 0 90
			)

			2:
			(
				RotValInv = EulerAngles 0 0 0
			)
		)

		animate off in coordsys local
		(
			--obj.objectoffsetrot *= (RotValInv as quat)
			obj.rotation *= inverse (RotValInv as quat)
			obj.objectoffsetrot *= inverse(RotValInv as quat)
		)
	)

	fn exportProcess ExportType aStart: aEnd: aSequenceName: aExport: OVERRIDEREDRAW: =
	(
		local r_start = ro_m.anim_range_start.value
		local r_end = ro_m.anim_range_end.value

		if (aStart != unsupplied) do (r_start = aStart)
		if (aEnd != unsupplied) do (r_end = aEnd)

		if (r_start == r_end) do (r_end = r_end + 1) --If range is 0 long, add one frame to export properly

		local pro = projectArray[currentProjectSelected] as string

		--Update filename to base asset name from
		gName = (getFilenameFile  maxFileName)

		thePlugin = pluginManager
		thePlugin.loadClass FBXEXPORTER

		FBXExporterSetParam "SmoothingGroups" True
		FBXExporterSetParam "TangentSpaceExport" True
		FBXExporterSetParam "ASCII" False
		FBXExporterSetParam "FileVersion" "FBX201400"
		FBXExporterSetParam "Cameras" False
		FBXExporterSetParam "Lights" False
		FBXExporterSetParam "PreserveInstances" True
		FBXExporterSetParam "ScaleFactor" 1.0
		FBXExporterSetParam "ShowWarnings" False

		local tempInterval = animationRange

		case ExportType of
		(
			1:
			(
				FBXExporterSetParam "Animation" False

				clearSelection()

				with redraw off
				(
					execute "$exportGroup"
				)
			)

			2:
			(
				FBXExporterSetParam "Animation" True

				FBXExporterSetParam "BakeAnimation" True
				FBXExporterSetParam "BakeResampleAnimation" True

				FBXExporterSetParam "BakeFrameStart" r_start
				FBXExporterSetParam "BakeFrameEnd" r_end

				--Resize active range to exporting range length to avoid "dead frames"
				animationRange = interval r_start r_end
			)
		)

		--Set export params
		FBXExporterSetParam "PushSettings"

		local p_length = ((getINISetting PBS pro "p_projectSource").count)
		local p_subPath = replace (maxFilePath as string) 1 (p_length) ""

		--Build final path to file export location
		if (s_ImportFromRaw == false) then
		(
			local p_fileExportPath = pathConfig.appendPath p_ProjectRoot p_subPath
		)
		else
		(
			local p_fileExportPath = (maxFilePath as string)
		)

		if (NOT doesFileExist p_fileExportPath OR NOT getFileAttribute p_fileExportPath #directory) do
		(
			--Path folder not found, create folder
			printc("Path folder not found, creating folder.")
			makeDir p_fileExportPath
		)

		if (aSequenceName != unsupplied) then
		(
			--Animation sequence naming
			fileExportName = (p_fileExportPath + (aSequenceName as string) + ro_a.FileExtension.text + ".fbx") as string
		)
		else
		(
			--Regular filename-based naming
			fileExportName = (p_fileExportPath + gName + ro_a.FileExtension.text + ".fbx") as string
		)

		exportfile (fileExportName) #noprompt selectedOnly:true using:thePlugin

		print("Exported at >> " + fileExportName)

		--[ Export accessory ]--
		if ((aExport != unsupplied AND aExport == true AND ro_m.ExportAccessory.state == true) OR (aExport == unsupplied AND ro_m.ExportAccessory.state == true)) do
		(
			local accessory = LocateAccessory pre: s_ac_Prefix

			if (accessory != undefined) do
			(
				getChildren(accessory)

				local accessoryExportName = ""

				local adjustedName = gName

				if (aSequenceName != unsupplied) do (adjustedName = (aSequenceName as string))

				local accessoryName = replace adjustedName 1 s_ac_RemoveFilePre s_ac_FilePrefix
				accessoryName = replace accessoryName (accessoryName.count - s_ac_RemoveFileSuf) s_ac_RemoveFileSuf s_ac_FileSuffix

				local accessoryFolder =  ((s_ac_Folder as string) + "\\")

				accessoryExportName = (p_fileExportPath + accessoryFolder + accessoryName + ro_a.FileExtension.text + ".fbx") as string

				exportfile (accessoryExportName) #noprompt selectedOnly:true using:thePlugin

				print("Exported accessory at >> " + accessoryExportName)
			)
		)

		--[ Finish up export sequence]--
		animationRange = tempInterval

		clearSelection()

		if (OVERRIDEREDRAW == unsupplied) then
		(
			enableSceneRedraw()
		)
		else
		(
			if (OVERRIDEREDRAW == false) do (enableSceneRedraw())
		)

	)

	--Dependency class
	fn PrepareMeshForExport group_mesh generate_lods lods_amount =
	(
		RefreshRollouts()

		local ObjectSelection = selection as array

		if (currentAssetSelected != 1) do
		(
			MessageBox "Current asset type is not set to Geometry!" title:"Wrong asset type!"
			return()
		)

		if (ObjectSelection.count == 0 and group_mesh == false) do
		(
			print("Nothing selected, quitting...")
			return()
		)

		--Get exclusion node parent
		local excludeObject = getNodeByName "ExcludeExport"

		--Remove exclusion objects from export selection, ignore pass if no object is found
		if (excludeObject != undefined) do
		(
			printc("Found exclusion node!")

			local RemoveObjectsSelection = getChildren(excludeObject)

			for i = 1 to RemoveObjectsSelection.count do
			(
				local findQue = findItem ObjectSelection RemoveObjectsSelection[i]

				if (findQue != 0) do
					deleteItem ObjectSelection findQue
			)
		)

		global cleanGroup = #()
		global exportGroup = #()
		global GroupArray = #()

		free cleanGroup
		free exportGroup
		free GroupArray

		try
		(
			disableSceneRedraw()

			with undo off
			(
				--Create root export object for axis conversion
				local ExportParent = Point Size:500 Name:"ExportParent"
				RotatePivotOnlyEngine(ExportParent)
				FreezeTransforms(ExportParent)

				append exportGroup ExportParent
				append cleanGroup ExportParent

				--Clone export objects for non-destructive processing
				local SafeCopies = #()

				--Copy export objects into a "safe selection" in case something goes wrong
				CopyNodes ObjectSelection #copy &SafeCopies
				append cleanGroup SafeCopies

				--Make all instances in selection unique (Will be ignored otherwise)
				InstanceMgr.MakeObjectsUnique SafeCopies #individual

				--Clear selection to set up proper selection for export
				clearSelection()
				select SafeCopies

				if (s_MeshGroupPrefix == undefined) do (s_MeshGroupPrefix = "g_")

				--Assume there are no mesh group objects in scene
				local validGroupObjects = false

				--Collect mesh groups in selection
				for obj in SafeCopies do
				(
					if (matchPattern obj.name pattern:(s_MeshGroupPrefix + "*") == true) do
					(
						printc("Found group object: " + obj.name + " - adding to array")
						append GroupArray obj

						validGroupObjects = true
					)
				)

				if (group_mesh == true and validGroupObjects == true) then
				(
					--Process mesh groups
					for g in GroupArray do
					(
						printc("\n")
						printc("[---------Creating Mesh Group---------]")
						printc("Group object: " + g.name)

						clearSelection()
						select g.children

						local CombiningGroup = FilterForMeshes(selection)

						printc("\nGroup objects {")
						printc(CombiningGroup as array)

						local GroupName = replace (trimRight (g.name as string) "0123456789") 1 s_MeshGroupPrefix.count ""

						local GroupParent = Point Size:100 Name:(("g_" + GroupName) as string)
						RotatePivotOnlyEngine(GroupParent)
						append exportGroup GroupParent
						append cleanGroup GroupParent

						local CombinedMesh = Editable_Mesh name:(("mg_" + GroupName) as string)
						convertTo CombinedMesh Editable_Poly

						GroupParent.parent = ExportParent
						GroupParent.position = g.position
						CombinedMesh.position = g.position

						printc("\nCombined mesh: " + CombinedMesh.name)
						printc("\n[Starting grouping process]\n")

						for c in CombiningGroup do
						(
							collapseStack c
							convertTo c Editable_Poly

							printc("Adding mesh [ " + c.name + " ] to: " + CombinedMesh.name)

							polyop.attach CombinedMesh c
						)

						--Fix pivot
						if (ZeroPivotToOrigin == true) then
						(
							in coordsys world CombinedMesh.objectOffsetPos = [0,0,0]
							in coordsys world CombinedMesh.objectOffsetRot = (eulerangles 0 0 0)
							(_rotation as quat)
						)
						else
						(
							ResetTransform CombinedMesh
						)

						if (UnlinkFromParent == true)
						then
						(CombinedMesh.parent = ExportParent)
						else
						(CombinedMesh.parent = GroupParent)

						RotatePivotOnlyEngine(CombinedMesh)

						--Add combined object to group
						append exportGroup CombinedMesh
						append cleanGroup CombinedMesh
					)
				)
				else
				(
					--Regular export selection
					local CombiningGroup = FilterForMeshes(selection)

					for i = 1 to CombiningGroup.count do
					(
						c = CombiningGroup[i]

						collapseStack c
						convertTo c Editable_Poly

						local CurrentParent = c.parent
						c.parent = undefined

						if (UnlinkFromParent == true) then
						(
							c.parent = ExportParent
						)
						else
						(
							if (CurrentParent == undefined) then (c.parent = ExportParent) else (c.parent = CurrentParent)
						)

						RotatePivotOnlyEngine(c)

						append exportGroup c
						--append cleanGroup c
					)
				)
			)
		)
		catch
		(
			enableSceneRedraw()

			if (cleanGroup != undefined) do
			(
				if (cleanGroup.count >= 1) do
				(
					for o in cleanGroup do
					(
						try(delete o)catch()
					)
				)
			)

			if (SafeCopies != undefined) do
			(
				if (SafeCopies.count >= 1) do
				(
					for o in SafeCopies do
					(
						try(delete o)catch()
					)
				)
			)

			--Already deleted I guess?
			--delete ExportParent

			messageBox "Something went wrong!" title:"Error"

			return()
		)

		if (generate_lods) do
		(
			local LodMeshsGroups = FilterForMeshes exportGroup
			LodGenerator LodMeshsGroups lods_amount
		)

		--Done!
		printc("\nOperation done!")
		printc("Export group {")
		printc(exportGroup)

		rotate ExportParent (eulerangles 0 0 -90)

		--Collect combined objets and export them, then clean em' out
		clearSelection()
		select exportGroup

		exportProcess 1

		clearSelection()

		for o in cleanGroup do
		(
			try(delete o)catch()
		)

		for o in SafeCopies do
		(
			try(delete o)catch()
		)

		free cleanGroup
		free exportGroup
	)


	rollout UI_RolloutGroup_Main "Export"
    (
		group "Mesh"
		(
			button Export "Export" width:94 pos:[14,22]
			button ExportSelection "Export Selection" width:94 pos:[116,22]
		)

		group "Animation"
		(
			button ExportAnimation "Export Animation" width:94 pos:[14, 70]

			spinner anim_range_start "" pos:[115,73] width:42 height:16 range:[-10000,10000,normTime 0] type:#integer
			spinner anim_range_end  "to " pos:[115+54,73] width:42 height:16 range:[-10000,10000,normTime 1] type:#integer

			button EditSequences "Edit sequences" pos:[118, 95]

			checkbox ExportSequences "Exp Sequences" pos:[15, 95]
			checkbox ExportAccessory "Exp Accessory" pos:[15, 112]
		)

		on UI_RolloutGroup_Main rolledUp State do (resizeWindow PipeBoy UI_RolloutGroup_Main State)

		on Export pressed do
		(
			LoadVariables() -- Double check saved variables
			RefreshRollouts() --Same for rollouts

			select $*

			if (selection.count == 0) do (return())

			if ((getFilenameFile  maxFileName) == "") do
			(
				MessageBox "Save scene first!" title:"Export error!"
				return()
			)

			if (ro_a == undefined) do (RefreshRollouts())

			PrepareMeshForExport ro_a.meshGrouper.state ro_a.generateLods.state ro_a.lodsAmount
		)

		on ExportSelection pressed do
		(
			LoadVariables() -- Double check saved variables
			RefreshRollouts() --Same for rollouts

			if (selection.count == 0) do (return())

			if ((getFilenameFile  maxFileName) == "") do
			(
				MessageBox "Save scene first!" title:"Export error!"
				return()
			)

			if (ro_a == undefined) do (RefreshRollouts())

			PrepareMeshForExport ro_a.meshGrouper.state ro_a.generateLods.state ro_a.lodsAmount
		)

		on ExportAnimation pressed do
		(
			LoadVariables() -- Double check saved variables
			RefreshRollouts() --Same for rollouts

			if ((getFilenameFile  maxFileName) == "") do
			(
				MessageBox "Save scene first!" title:"Export error!"
				return()
			)

			clearSelection()

			try
			(
				disableSceneRedraw()

				local rootBone = getNodeByName (s_BoneRoot as string) ignoreCase:false

				if (rootBone == undefined) do
				(
					messageBox "Can't find root bone, check project settings! Case sensitive!" title:"No root bone!"
					return()
				)

				with redraw off
				(
					local nodeSelection = getChildren(rootBone)
					local boneSelection = #()
				)

				print("Redraw disabled?: " + (isSceneRedrawDisabled() as string))

				for i = 1 to nodeSelection.count do
				(
					obj = nodeSelection[i]

					boneMatchResult = matchPattern (obj.name) pattern:((s_BonePrefix as string) + "*") ignoreCase:false
					alignMatchResult = matchPattern (obj.name) pattern:((s_AlignPrefix as string) + "*") ignoreCase:false

					if (boneMatchResult == true OR alignMatchResult == true) do
					(
						append boneSelection obj
					)
				)

				clearSelection()

				if (ExportSequences.state == true) then
				(
					--Load fresh sequence data from .boi file!
					LoadSequences()

					--print("Sequences: " + SequenceArray as string)

					--return()
					for s in SequenceArray do
					(
						--Re-select each pass
						select boneSelection

						--print("Exporting sequence #" + (s as string) + "...")

						local aName = s.s_Name
						local aStart = s.s_Range_Start
						local aEnd = s.s_Range_End
						local aExp = s.s_ExportAccessory

						exportProcess 2 aStart: aStart aEnd: aEnd aSequenceName: aName aExport: aExp OVERRIDEREDRAW:true
					)
				)
				else
				(
					with redraw off
					(
						--Do single selection pass
						select boneSelection

						--print("Do regular export")
						exportProcess 2
					)
				)
			)
			catch
			(
				--Re-enable scene redrawing if error occurs
				enableSceneRedraw()
			)

			--Backup enable
			enableSceneRedraw()

		)

		on EditSequences pressed do
		(
			--Open rollout from external file
			fileIn PipeBoyAnimSetup
		)

    )

	rollout UI_RolloutGroup_Asset "Asset Settings"
    (
		group "Asset Settings"
		(
			dropdownlist IsType "Asset Type" items:#("Geometry", "Animation") width:125

			checkbox meshGrouper "Mesh grouper" checked:false
			checkbox generateLods "Generate lods" checked:false
			spinner lodsAmount "Lods" range:[1,6,2] type:#integer width:50 pos:[125, 92]
			editText FileExtension "File name extension"
		)

		on IsType selected NewType do
		(
			currentAssetSelected = NewType
		)

		on UI_RolloutGroup_Asset open do
		(
			IsType.selection = currentAssetSelected
		)

		on UI_RolloutGroup_Asset rolledUp State do (resizeWindow PipeBoy UI_RolloutGroup_Asset State)

		on UI_RolloutGroup_Asset open do
		(
			UI_RolloutGroup_Asset.open = false
		)

    )

	rollout UI_RolloutGroup_General "General Settings"
    (
		group "General Settings"
		(
			checkbox ZeroPivot "Zero Pivot" checked:false
			checkbox Unlink "Unlink" checked:false
			checkbox PrintMessages "Print to log?" checked:PrintToConsole
		)

		on PrintMessages changed newState do
		(
			PrintToConsole = newState
		)

		on Unlink changed newState do
		(
			UnlinkFromParent = newState
		)

		on ZeroPivot changed newState do
		(
			ZeroPivotToOrigin = newState
		)

		on UI_RolloutGroup_General rolledUp State do (resizeWindow PipeBoy UI_RolloutGroup_General State)

		on UI_RolloutGroup_General open do
		(
			UI_RolloutGroup_General.open = false
		)

    )

	rollout UI_RolloutGroup_Project "Project Settings"
    (
		group "Project Settings"
		(
			dropdownlist currentProject "Project" width:125
			button refreshProjects "Refresh" pos:[148,44]
		)

		group ""
		(
			button editProjectSettings "Edit project settings" align:#center
		)

		on UI_RolloutGroup_Project open do
		(
			UI_RolloutGroup_Project.open = false
		)

		on UI_RolloutGroup_Project rolledUp State do (resizeWindow PipeBoy UI_RolloutGroup_Project State)

		on editProjectSettings pressed do
		(
			fileIn PipeBoySettings
		)

		on currentProject selected newProject do
		(
			if (newProject != undefined) then
			(
				currentProjectSelected = currentProject.selection
				LoadVariables()
			)
			else
			(
				MessageBox "Project seems to be missing!" title:"Missing project!"
				currentProjectSelected = 1
			)
		)

		on refreshProjects pressed do
		(
			LoadVariables()

			currentProject.items = projectArray
		)

    )

	on PipeBoy open do
	(
		--Fix initialized persistent variables
		if (currentProjectSelected == 0  OR currentProjectSelected == undefined) do (currentProjectSelected = 1)
		if (currentAssetSelected == 0  OR currentAssetSelected == undefined) do (currentAssetSelected = 1)
		if (PrintToConsole == undefined) do (PrintToConsole = false)

		addSubRollout UI_Base UI_RolloutGroup_Main
		addSubRollout UI_Base UI_RolloutGroup_Asset
		addSubRollout UI_Base UI_RolloutGroup_General
		addSubRollout UI_Base UI_RolloutGroup_Project

		global ro_m = PipeBoy.UI_RolloutGroup_Main
		global ro_a = PipeBoy.UI_RolloutGroup_Asset
		global ro_g = PipeBoy.UI_RolloutGroup_General
		global ro_p = PipeBoy.UI_RolloutGroup_Project

		ro_a.IsType.selection = 1

		PBS = (pathConfig.GetDir #userScripts) + ( "\\MaxBoy\\PipeBoy_Settings.ini")
		PipeBoySettings = (pathConfig.GetDir #userScripts) + ( "\\MaxBoy\\PipeBoy_ProjectSettings.ms")
		PipeBoyAnimSetup = (pathConfig.GetDir #userScripts) + ( "\\MaxBoy\\PipeBoy_AnimSetup.ms")

		--Setup interface data
		LoadVariables()

		ro_p.currentProject.items = projectArray
		ro_p.currentProject.selection = currentProjectSelected

		enableSceneRedraw()
		renderSceneDialog.update()
	)
)

try(destroyDialog PipeBoy)catch()
createDialog PipeBoy style:#(#style_toolwindow, #style_sysmenu) pos:[1100,150] width:235 height:90
)
