/*////////////////////////////////////////////////
PipeBoy is a pipeline tool that strives to improve
general workflows for game-related asset creation.
////////////////////////////////////////////////*/

--Start PipeBoy--
(--start local scope
include "$userscripts\maxboy\maxboy_functions.ms"

--Initialize persistent globals
persistent global GP_CurrentProjectSelected
persistent global GP_AssetTypeSelection
persistent global GP_PrintToConsole

--Misc menu settings memory
persistent global GP_MeshGrouper
persistent global GP_GenerateLODs
persistent global GP_SeparateMeshFiles
persistent global GP_UseSequenceList
persistent global GP_ExportAccessory
persistent global GP_Character
persistent global GP_Accessory

--Global rollout references
global ro_m
global ro_s
global ro_a
global ro_p

--Remember which panels are open (bools)
persistent global ro_open_m
persistent global ro_open_s
persistent global ro_open_a
persistent global ro_open_p

--Initialize globals
global PipeBoyInitialized --Delay setting persistent vars and other update functions
global gname = (getfilenamefile  maxfilename)
global PipeBoy --rollout class handle
global PipeBoysettings = (pathconfig.getdir #userscripts) + ( "\\maxboy\\PipeBoy_projectsettings.ms") --PipeBoy settings file
global PipeBoyanimsetup = (pathconfig.getdir #userscripts) + ( "\\maxboy\\PipeBoy_animsetup.ms") --PipeBoy animation setup file
global PipeBoySub --Subrollout inside main PipeBoy rollout
global PBS = (pathconfig.getdir #userscripts) + ( "\\maxboy\\PipeBoy_settings.ini") --PipeBoy settings .ini file handle
global PipeBoy_FloaterWindowHeight --Height of floater
global ExportTimerStart
global ExportTimerEnd

--Temp arrays
global TMP_ExportGroup = #()
global TMP_ExportResults = #()
global TMP_CleanGroup = #()
global TMP_ProjectArray = #()
global TMP_SequenceArray = #()

--Settings struct
struct LocalSettings
(
	p_projectRoot, 		--String
	p_projectSource, 	--String
	p_projectAsset, 	--String

	s_Engine, 			--Integer
	s_ImportFromRaw, 	--booleanClass
	s_PreferredPrefixes,--String
	s_ForwardAxis, 		--Integer
	s_MeshGroupPrefix, 	--String

	s_BonePrefix, 		--String
	s_BoneRoot, 		--String
	s_AlignPrefix, 		--String

	s_ac_Folder,		--String
	s_ac_Prefix, 		--String
	s_ac_FindIntelligent,--booleanClass
	s_ac_LockRoot, 		--booleanClass
	s_ac_LockRootDepth, --Integer

	s_ac_FilePrefix,	--String
	s_ac_FileSuffix,	--String
	s_ac_RemoveFilePre,	--Integer
	s_ac_RemoveFileSuf  --Integer
)

--Sequence struct
struct sequence
(
	sequenceName		= "null",   --string
	exportAccessory		= false, 	--booleanclass
	range_start 		= 0, 		--integer
	range_end 			= 1 		--integer
)

--Initialize local settings "container" to easily store and update for later
global LS = LocalSettings()

--Dependent include (Sub-Floater)
include "$userscripts\maxboy\pipeboy_animsetup.ms"
include "$userscripts\maxboy\pipeboy_projectsettings.ms"

--load from .boi file
fn LoadSequences =
(
	--call garbage collection to avoid i/o issues
	gc()

	if (maxfilename == "") do
	(
		printc("Won't attempt sequence load - scene is unsaved")
		return()
	)

	--remove file name's extension
	local filteredName = (filterString (maxFileName as string) ".")[1]
	local relativePath = ((GetDir #userScripts + "\\MaxBoy\\AnimSetup\\") + filteredName + ".boi")

	--convert to valid search path
	local filepath = ConvertToPath relativePath

	if (DoesFileExist filepath == false) do
	(
		printc("No file to load from @ " + (relativePath as string))
		free TMP_SequenceArray
		return()
	)

	local ofile = openfile filepath mode:"r"

	if (ofile != undefined) then
	(
		--print("loading sequences from >> " + relativePath)
		TMP_SequenceArray = #()

		local i = 0

		do
		(
			i += 1

			local checkcurrent = ("[PipSeq_" + (i as string) + "]")

			local searchresult = skiptostring ofile checkcurrent

			if (searchresult != undefined) do
			(
				local skippos = ((filepos ofile) + 2)

				--start reading sequence data
				seek ofile skippos

				local r_name = (readline ofile as string)

				local r_expa = (readvalue ofile as booleanclass)
				local r_fsta = (readvalue ofile as integer)
				local r_fend = (readvalue ofile as integer)

				local loadsequence = sequence sequenceName:(r_name) exportAccessory:r_expa range_start:r_fsta range_end:r_fend

				append TMP_SequenceArray loadsequence
			)
		) while (searchresult != undefined)

		close ofile

		--print("sequence array >> " + TMP_SequenceArray as string)
		if (TMP_SequenceArray.count == 0) then
		(
			printc("Load Sequences :: [ Found (.boi) file, but found no sequences! ]")
		)
		else
		(
			printc("Load Sequences :: [ Loaded (" + (TMP_SequenceArray.count as string) + ") sequences from file ]")
		)
	)
	else
	(
		printc("Load Sequences :: [ Couldn't find (.boi) file to open! ]")
	)

	--Moved to trigger on UI update instead
	--cbf_updateui()
)

fn cbf_updateui =
(
	--Don't update UI until we're fully booted up!
	if (PipeBoyInitialized == false) do ( return() )

	--Load related settings
	LoadProjectSettings()

	--Load related scene sequence list
	LoadSequences()

	if (ro_m != undefined) then
	(
		ro_m.UI_AnimRange_Start.value = normtime 0
		ro_m.UI_AnimRange_End.value = normtime 1
	)
	else ( printc("UpdateUI :: rollout main is undefined!") )

	if (ro_a != undefined) then
	(
		--Do asset related UI updating
	) else ( printc("UpdateUI :: rollout animation is undefined!") )

	if (ro_s != undefined) then
	(
		fn TryGetRootNode =
		(
			local rootNodeResult = (GetRootNodes())[1]

			if (rootNodeResult != undefined) do
			(
				ro_s.UI_PickCharacter.object = rootNodeResult
				ro_s.UI_PickCharacter.text   = rootNodeResult.name
			)
		)

		local itemList = #()

		--Update sequence list UI
		for s in TMP_SequenceArray do
		(
			if (s != undefined) then
			(
				local ea = (s.exportAccessory as booleanClass)
				local rs = (s.range_start as integer)
				local re = (s.range_end as integer)

				local seqName = s.sequenceName + (" [" + (rs as string) + " : " + (re as string) + "]")

				if (ea) do ( append seqName " #A" )

				append itemList seqName
			)
			else
			(
				print("UpdateUI :: Sequence is invalid!")
			)
		)

		ro_s.UI_List_Sequences.items = itemList

		--Update prefix lists
		local searchSelection = $*

		local prefixes = join (#("---")) (FindPrefixesInScene())

		ro_s.UI_Rig_Character.items = prefixes
		ro_s.UI_Rig_Accessory.items = prefixes

		--Only attempt finding the preferred prefix if it's set to null to begin with
		if (ro_s.UI_Rig_Character.selection == 1) do
		(
			--Try and find best prefix for character rig
			for p in prefixes do
			(
				local pfArr = filterString LS.s_PreferredPrefixes ", "
				local matchResult = MatchPatternMultiple str:p patterns:pfArr matchAll:false ind:&foundIndex

				if (foundIndex != undefined) then
				(
					matchResult = RemoveLastChar matchResult

					local inList = findItem prefixes p --Get index of preferred prefix
					ro_s.UI_Rig_Character.selection = inList --Apply selection to list of prefixes

					break
				)
				else
				(
					--DON'T reset prefix selection if preferred wasn't found!!!
					--ro_s.UI_Rig_Character.selection = 1
				)
			)
		)

		--If pick character is not selected, try and find a good match
		if (ro_s.UI_PickCharacter.object == undefined) then
		(
			TryGetRootNode()
		)
		else
		(
			if (isValidNode ro_s.UI_PickCharacter.object == false) do
			(
				TryGetRootNode()
			)
		)
	)
	else ( printc("UpdateUI :: rollout sequence is undefined!") )

	printc("Updated UI")
) global cbf_updateui_fn = cbf_updateui --store as global varaible

fn GenerateLOD &obj lods =
(
	ClearSelection()
	DisableSceneRedraw()

	try
	(
	with undo off
	(
		for lodobj in obj do
		(
			try
			(
				local removeobjfromexport = finditem TMP_ExportGroup lodobj
				deleteitem TMP_ExportGroup removeobjfromexport
			)
			catch
			(
				print("couldn't delete object from export group!")

				throw()
			)


			local safelodcopy = CopyNodes collection:lodobj
			append TMP_CleanGroup safelodcopy

			templodobj = safelodcopy[1]
			templodobj.name = ((trimright lodobj.name "0123456789") + "_lod0")

			append TMP_ExportGroup templodobj

			for i = 1 to lods do
			(
				safelodstepcopy = CloneNodes collection:templodobj

				append TMP_CleanGroup safelodstepcopy
				lodstepobject = safelodstepcopy[1]
				lodstepobject.name = ((trimright templodobj.name "0123456789") +  i as string)

				optimizer = prooptimizer optimizationmode:1

				optimizer.vertexpercent = (75 / i)
				optimizer.keepuv = true
				optimizer.lockuv = true

				optimizer.keepnormals = true
				optimizer.keepvc = true

				optimizer.mergepoints = true
				optimizer.mergepointsthreshold = 5

				addmodifier lodstepobject optimizer

				clearselection()
				select lodstepobject

				$.modifiers[#prooptimizer].calculate = true
				collapsestack lodstepobject
				convertto lodstepobject editable_poly

				--lodstepobject.position.y += (250 * i)

				append TMP_ExportGroup lodstepobject

				--free lodstepobject
			)

			--free templodobj
		)
	)
	)
	catch(EnableSceneRedraw())

	EnableSceneRedraw()
	clearselection()
)

fn GetExportLocation =
(
	--Trim full file path name with project source path
	local p_length = (LS.p_projectsource.count)
	local p_subpath = replace (maxfilepath as string) 1 (p_length) ""

	--Build final path to file export location (Source or project location)
	local p_fileexportpath = p_fileexportpath = pathconfig.appendpath LS.p_projectRoot p_subpath

	if (LS.s_importfromraw) do
	(
		p_fileexportpath = (maxfilepath as string)
	)

	--Return resulting path
	return p_fileexportpath
)

fn PostExportCleanup =
(
	if (TMP_CleanGroup != undefined) do
	(
		for o in TMP_CleanGroup do ( if (isValidnode o) do ( delete o ) )
		free TMP_CleanGroup
	)

	if (safecopies != undefined) do
	(
		for o in safecopies do ( if (isValidnode o) do ( delete o ) )
		free safecopies
	)

	if (TMP_ExportGroup != undefined) do
	(
		for o in TMP_ExportGroup do ( if (isValidnode o) do ( delete o ) )
		free TMP_ExportGroup
	)

	return()
)

fn TryExportCriteria trySelection:false tryCharacter:false =
(
	if ((getfilenamefile  maxfilename) == "") do
	(
		messagebox "Save scene first!" title:"Export error!"
		return false
	)

	if (trySelection) do
	(
		if (selection.count == 0) do
		(
			messagebox "Empty selection!" title:"Export error!"
			return false
		)
	)

	if (tryCharacter) do
	(
		local cSel = ro_s.UI_Rig_Character.selection
		local aSel = ro_s.UI_Rig_Accessory.selection

		local cSelPick = ro_s.UI_PickCharacter.object
		local aSelPick = ro_s.UI_PickAccessory.object

		local aExp = ro_s.UI_ExportAccessory.checked

		if (aExp) then
		(
			--Check prefix based pick first
			if (cSel > 1 and aSel > 1) then
			(
				if (cSel == aSel) do
				(
					MessageBox "Character and Accessory rigs are marked as the same!" title:"Export Error!"
					return false
				)
			)
			else
			(
				--Check if picknodes are set
				if (cSelPick == undefined) do
				(
					MessageBox "No Character rig has been defined!" title:"Export Error!"
					return false
				)

				if (aSelPick == undefined) do
				(
					MessageBox "No Accessory rig has been defined! Don't want to export accessory? Uncheck the 'Accessory' checkbox!" title:"Export Error!"
					return false
				)

				--Compare the pickbutton nodes to see if they're the same, but only if they're set
				if (cSelPick == aSelPick) do
				(
					MessageBox "Character and Accessory rigs are marked as the same! These need to be set as different bone structures!" title:"Export Error!"
					return false
				)
			)
		)
		else
		(
			--Check if character rig has been set (If we fail both prefix and pickbutton options- return as false)
			if (cSel <= 1 and cSelPick == undefined) do
			(
				MessageBox "No Character rig has been defined!" title:"Export Error!"
				return false
			)
		)
	)

	return true
)

--Base UI height
local baseHeight = 94

rollout PipeBoy "PipeBoy"
(
	--construct base ui "frame" for rollout windows
	subrollout ui_base width:235 height:baseHeight pos:[0,0]

	--window resize function for rollouts [ override ]
	fn ResizeFloaterWindow ro =
	(
		try
		(
			local fold = if (ro.open) then 1 else -1

			ui_base.height += ro.height * fold
			PipeBoy.height += ro.height * fold

		    cbf_updateui()
	    )
	    catch
	    (
	    	print("ResizeFloaterWindow :: Rollout folding error! Rollout >> " + (ro as string))
	    	throw()
	    )
	)

	fn UI_RefreshRollouts =
	(
		ro_m = PipeBoy.ui_rolloutgroup_main
		ro_s = PipeBoy.ui_rolloutgroup_sequence
		ro_a = PipeBoy.ui_rolloutgroup_asset
		ro_p = PipeBoy.ui_rolloutgroup_project

		PipeBoySub = ui_base

		PipeBoy_FloaterWindowHeight = (ro_m.height + ro_s.height + ro_a.height + ro_p.height) + 105
	)

	fn RotateEnginePivot obj =
	(
		/*
		1 = x-forward
		2 = - x-forward
		3 = y-forward
		4 = - y-forward
		*/

		local rotvalinv --set up local rotation variable

		case LS.s_engine of
		(
			--local rotvalinv = case LS.s_forwardaxis of

			1:
			(
				rotvalinv = eulerangles 90 0 90
			)

			2:
			(
				rotvalinv = eulerangles 0 0 0
			)
		)

		animate off in coordsys local
		(
			--obj.objectoffsetrot *= (rotvalinv as quat)
			obj.rotation *= inverse (rotvalinv as quat)
			obj.objectoffsetrot *= inverse(rotvalinv as quat)
		)
	)

	fn ExportProcess collection: exportType:1 astart: aend: asequencename: aexport:false batch:false =
	(
		local exportCollection = #()

		--Do this rather than supply default to have it autimatically pick TMP_ExportGroup if unsupplied
		if (collection == unsupplied) then ( exportCollection = TMP_ExportGroup ) else ( exportCollection = collection)

		local r_start = ro_m.UI_AnimRange_Start.value
		local r_end = ro_m.UI_AnimRange_End.value

		if (astart != unsupplied) do (r_start = astart)
		if (aend != unsupplied) do (r_end = aend)

		if (r_start == r_end) do (r_end = r_end + 1) --if range is 0 long, add one frame to export properly

		--[Set up file naming base variables]--
		--Update filename to base asset name from
		gname = (getfilenamefile  maxfilename)

		local p_fileexportpath = GetExportLocation()

		--Make missing destination folders in windows if they're missing
		if (not doesfileexist p_fileexportpath or not getfileattribute p_fileexportpath #directory) do
		(
			--path folder not found, create folder
			printc("Mirrored export folder not found, creating new folder...")
			makedir p_fileexportpath
		)

		--Filename-based naming as a baseline
		local FileExportName = (p_fileexportpath + gname + ro_a.UI_FileExtension.text + ".fbx") as string

		--Only select defined collection for export
		ClearSelection()
		--select exportCollection
		SelectMore exportCollection

		if (batch == false) do
		(
			printc("[ Export selection ]")
			printc(selection)
		)

		theplugin = pluginmanager
		theplugin.loadclass fbxexporter

		--Setup base export params
		fbxexportersetparam "smoothinggroups" true
		fbxexportersetparam "tangentspaceexport" true
		fbxexportersetparam "ascii" false
		fbxexportersetparam "fileversion" "fbx201400"
		fbxexportersetparam "cameras" false
		fbxexportersetparam "lights" false
		fbxexportersetparam "preserveinstances" true
		fbxexportersetparam "scalefactor" 1.0
		fbxexportersetparam "showwarnings" false

		local tempinterval = animationrange

		case exportType of
		(
			1:
			(
				--Setup type specific export params
				fbxexportersetparam "animation" false
				fbxexportersetparam "pushsettings"

				--Perform export operation
				ExportFile FileExportName #noprompt selectedonly:true using:theplugin

				if (batch == false) then ( print("Exported at >> " + FileExportName as string) ) else ( append TMP_ExportResults ("Exported at >> " + FileExportName) )
			)

			2:
			(
				--Setup type specific export params
				fbxexportersetparam "animation" true
				fbxexportersetparam "bakeanimation" true
				fbxexportersetparam "bakeresampleanimation" true
				fbxexportersetparam "bakeframestart" r_start
				fbxexportersetparam "bakeframeend" r_end
				fbxexportersetparam "pushsettings"

				--Resize active range to exporting range length to avoid "dead frames"
				animationrange = interval r_start r_end

				--Modify filename if we're using sequence list
				if (asequencename != unsupplied) do
				(
					--animation sequence naming
					FileExportName = (p_fileexportpath + (asequencename as string) + ro_a.UI_FileExtension.text + ".fbx") as string
				)

				--Grab selection
				clearSelection()
				selectmore exportCollection

				--Perform export operation
				ExportFile FileExportName #noprompt selectedonly:true using:theplugin

				if (batch == false) then ( print("Exported at >> " + FileExportName as string) ) else ( append TMP_ExportResults ("Exported at >> " + FileExportName) )

				--[ Export accessory ]--
				if (aexport == true) do
				(
					local aSel = ro_s.UI_Rig_Accessory.selection

					local accessoryCopies = undefined

					if (aSel != 1) then
					(
						local accessoryChildren = GetPrefixObjects pre:ro_s.UI_Rig_Accessory.selected allowMeshes:true
						accessoryCopies = CopyNodes collection:accessoryChildren
					)
					else
					(
						--local accessory = GetAccessory pre:LS.s_ac_prefix
						local accessory = ro_s.UI_PickAccessory.object

						if (isValidNode accessory) do
						(
							local accessoryChildren = GetChildren obj:accessory
							accessoryCopies = CopyNodes collection:accessoryChildren
						)
					)

					if (accessoryCopies != undefined) then
					(
						StripPrefixes(accessoryCopies)

						printc("[ Accessory Nodes ]")
						printc(accessoryCopies)

						if (LS.s_ac_lockroot == true) do
						(
							--Start with baking down rig bones to release constraints
							BakeKeys collection:accessoryCopies rs:r_start re:r_end DelayPrintArr:&TMP_ExportResults

							--Set up root constraints
							local rootLocker = point name:"RootLocker" size:20

							pc = Position_Constraint()
					        oc = Orientation_Constraint()

					        pcc = pc.constraints
					        pcc.appendTarget rootLocker 100.0

					        occ = oc.constraints
					        occ.appendTarget rootLocker 100.0

					        --Apply constraints in certain depth in rig
					        for i = 1 to LS.s_ac_LockRootDepth do
					        (
					        	try
					        	(
					        		accessoryCopies[i].pos.controller = pc
									accessoryCopies[i].rotation.controller = oc
			        			)
			        			catch
			        			(
			        				printc("Accessory node is null! Unable to zero accessory root!")
			        				throw()
			        			)
					        )
						)

						--Only select defined collection for export
						clearSelection()
						selectmore accessoryCopies

						local accessoryexportname = ""
						local adjustedname = gname

						if (asequencename != unsupplied) do (adjustedname = (asequencename as string))

						local accessoryname = replace adjustedname 1 LS.s_ac_removefilepre LS.s_ac_fileprefix
						accessoryname = replace accessoryname (accessoryname.count - LS.s_ac_removefilesuf) LS.s_ac_removefilesuf LS.s_ac_filesuffix

						local accessoryfolder =  ((LS.s_ac_folder as string) + "\\")

						accessoryexportname = (p_fileexportpath + accessoryfolder + accessoryname + ro_a.UI_FileExtension.text + ".fbx") as string

						--Make missing destination folders in windows if they're missing
						if (not doesfileexist (p_fileexportpath + accessoryfolder) or not getfileattribute (p_fileexportpath + accessoryfolder) #directory) do
						(
							--path folder not found, create folder
							printc("Accessory folder not found, creating folder.")
							makedir (p_fileexportpath + accessoryfolder)
						)

						ExportFile accessoryexportname #noprompt selectedonly:true using:theplugin

						for o in accessoryCopies do
						(
							if (isValidNode o) do
							(
								delete o
							)
						)

						if (isValidnode rootLocker) do (delete rootLocker)

						if (batch == false) then
						(
							print("Exported accessory at >> " + accessoryexportname)
						)
						else
						(
							append TMP_ExportResults ("Exported accessory at >> " + accessoryexportname)
						)
					)
					else
					(
						print("Export :: No accessory found!")
					)
				)

				--[ Finish up after export ]--
				animationrange = tempinterval
			)

			3:
			(
				--Setup type specific export params
				fbxexportersetparam "animation" false
				fbxexportersetparam "pushsettings"

				--Perform export operation
				for e_mesh in exportCollection do
				(
					if (e_mesh != undefined) do
					(
						--Skip targeting collision meshes (Wait for actual mesh to bring collision with it) AND folder nodes AND export parent node
						if ((matchpattern e_mesh.name pattern:("UCX_*") == false) and
							(matchpattern e_mesh.name pattern:("UBX_*") == false) and
							(matchpattern e_mesh.name pattern:("UCP_*") == false) and
							(matchpattern e_mesh.name pattern:("USP_*") == false) and
							(matchpattern e_mesh.name pattern:("FLD_*") == false) and
							(matchpattern e_mesh.name pattern:("exportparent") == false)) do
						(
							clearSelection()

							local exportSelectionSeparated = #(e_mesh)

							--Get customized collision for unreal
							local convexSearchString  = ("UCX_" + e_mesh.name) as string
							local boxSearchString     = ("UBX_" + e_mesh.name) as string
							local capsuleSearchString = ("UCP_" + e_mesh.name) as string
							local sphereSearchString  = ("USP_" + e_mesh.name) as string

							/*--Previous approach included all numbered versions...
							local convexSearchString  = ("UCX_" + e_mesh.name + "*") as string
							local boxSearchString     = ("UBX_" + e_mesh.name + "*") as string
							local capsuleSearchString = ("UCP_" + e_mesh.name + "*") as string
							local sphereSearchString  = ("USP_" + e_mesh.name + "*") as string
							*/

							for n in $* do
							(
								if ((matchpattern n.name pattern:(convexSearchString)  == true) or
									(matchpattern n.name pattern:(boxSearchString)     == true) or
									(matchpattern n.name pattern:(capsuleSearchString) == true) or
									(matchpattern n.name pattern:(sphereSearchString)  == true))do
								(
									append exportSelectionSeparated n
								)
							)

							select exportSelectionSeparated

							--Base filename on mesh name
							local MeshFileName = (p_fileexportpath + e_mesh.name + ro_a.UI_FileExtension.text + ".fbx") as string

							--Try and apply folder structure based on parent type
							if (e_mesh.parent != undefined) do
							(
								if (matchpattern e_mesh.parent.name pattern:("FLD_*") == true) do
								(
									local folderName = replace e_mesh.parent.name 1 4 ""
									local folderPath = (p_fileexportpath + folderName + "\\")

									--Make missing destination folders in windows if they're missing
									if (not doesfileexist folderPath or not getfileattribute folderPath #directory) do ( makedir folderPath )

									--Modify filename to match folder parent naming
									MeshFileName = (folderPath + e_mesh.name + ro_a.UI_FileExtension.text + ".fbx") as string
								)
							)

							ExportFile MeshFileName #noprompt selectedonly:true using:theplugin

							print("Exported file :: " + MeshFileName)
						)
					)
				)
			)
		)

		PostExportCleanup()

		clearselection()

		if (batch == false) do
		(
			EnableSceneRedraw()

			--Stop the timer, we're done!
			ExportTimerEnd = timeStamp()

			print(">> Exported file(s) in :: " + (((ExportTimerEnd - ExportTimerStart) / 1000.0) as string) + "s")
		)
	)

	fn PrepMesh collection:$* groupMesh:false lod:false lod_amount:3 =
	(
		UI_RefreshRollouts()

		local objectselection = collection as array

		if (objectselection.count == 0 and groupMesh == false) do
		(
			print("nothing selected, quitting...")
			return()
		)

		--get exclusion node parent
		local excludeobject = getnodebyname "excludeexport"

		--remove exclusion objects from export selection, ignore pass if no object is found
		if (excludeobject != undefined) do
		(
			printc("found exclusion node!")

			local removeobjectsselection = GetChildren obj:excludeobject

			for i = 1 to removeobjectsselection.count do
			(
				local findque = finditem objectselection removeobjectsselection[i]

				if (findque != 0) do
					deleteitem objectselection findque
			)
		)

		global grouparray = #()

		free TMP_CleanGroup
		free TMP_ExportGroup

		try
		(
			disablesceneredraw()

			with undo off
			(
				--create root export object for axis conversion
				local exportparent = point size:500 name:"exportparent"
				RotateEnginePivot(exportparent)
				FreezeTransforms(exportparent)

				append TMP_ExportGroup exportparent
				append TMP_CleanGroup exportparent

				--clone export objects for non-destructive processing
				local safecopies = CopyNodes collection:objectselection

				--append TMP_CleanGroup safecopies --PENDING DEPRECATION
				join TMP_CleanGroup safecopies

				--make all instances in selection unique (will be ignored otherwise)
				instancemgr.makeobjectsunique safecopies #individual

				if (LS.s_meshgroupprefix == undefined) do (LS.s_meshgroupprefix = "g_")

				--assume there are no mesh group objects in scene
				local validgroupobjects = false

				--collect mesh groups in selection
				for obj in safecopies do
				(
					if (matchpattern obj.name pattern:(LS.s_meshgroupprefix + "*") == true) do
					(
						printc("found group object: " + obj.name + " - adding to array")
						append grouparray obj

						validgroupobjects = true
					)
				)

				if (groupMesh == true and validgroupobjects == true) then
				(
					--process mesh groups
					for g in grouparray do
					(
						printc("\n")
						printc("[---------creating mesh group---------]")
						printc("group object: " + g.name)

						local meshSearchCollection = GetChildren obj:g
						local combininggroup = FilterMeshes(meshSearchCollection)

						printc("\ngroup objects {")
						printc(combininggroup as array)

						--local groupname = replace (trimright (g.name as string) "0123456789") 1 LS.s_meshgroupprefix.count ""
						local groupname = replace (g.name as string) 1 LS.s_meshgroupprefix.count ""

						local groupparent = point size:100 name:(("g_" + groupname) as string)
						RotateEnginePivot(groupparent)

						append TMP_ExportGroup groupparent
						append TMP_CleanGroup groupparent

						local combinedmesh = editable_mesh name:(("mg_" + groupname) as string)
						convertto combinedmesh editable_poly

						groupparent.parent = exportparent
						groupparent.position = g.position
						combinedmesh.position = g.position

						printc("\ncombined mesh: " + combinedmesh.name)
						printc("\n[starting grouping process]\n")

						for c in combininggroup do
						(
							collapsestack c
							convertto c editable_poly

							printc("adding mesh [ " + c.name + " ] to: " + combinedmesh.name)

							polyop.attach combinedmesh c
						)

						--fix pivot
						resettransform combinedmesh

						--Reparent mesh to group parent
						combinedmesh.parent = groupparent

						--Fix pivot orientation to engine specifics
						RotateEnginePivot(combinedmesh)

						--add combined object to group
						append TMP_ExportGroup combinedmesh
						append TMP_CleanGroup combinedmesh
					)
				)
				else
				(
					--regular export selection
					local combininggroup = FilterMeshes(safecopies)

					for c in combininggroup do
					(
						collapsestack c
						convertto c editable_poly

						local currentparent = c.parent
						c.parent = undefined

						--Fix parenting
						if (currentparent == undefined) then (c.parent = exportparent) else (c.parent = currentparent)

						--Fix pivot orientation to engine specifics
						RotateEnginePivot(c)

						append TMP_ExportGroup c
						--append TMP_CleanGroup c
					)
				)
			)
		)
		catch
		(
			EnableSceneRedraw()

			PostExportCleanup()

			messagebox "Something went wrong during mesh cooking!" title:"error"

			throw()
		)

		if (lod == true) do
		(
			local lodmeshsgroups = FilterMeshes TMP_ExportGroup
			GenerateLOD lodmeshsgroups lod_amount
		)

		--done!
		printc("\n Operation done!")
		printc("[ Export Group ]")
		printc(TMP_ExportGroup)

		rotate exportparent (eulerangles 0 0 -90)

		--Prep is done and applied to the export group, returning to called location
		return()
	)

	--UI main rollouts
	rollout ui_rolloutgroup_main "EXPORT"
    (
		group "General"
		(
			button UI_Export "Export" width:94 pos:[14, 22] tooltip:"Exports <ALL GEOMETRY> from scene"
			button UI_ExportSelection "Export Selection" width:94 pos:[116, 22] tooltip:"Exports all <SELECTED GEOMETRY> from scene"
		)

		group "Animation"
		(
			button UI_ExportAnimation "Export Animation" width:94 pos:[14, 70] tooltip:"Exports animation from scene from selected rigs in the 'Animation' tab"

			spinner UI_AnimRange_Start "" pos:[115, 73] width:42 height:16 range:[-10000, 10000, normtime 0] type:#integer tooltip:"Animation export's start frame"
			spinner UI_AnimRange_End  "to " pos:[115+54, 73] width:42 height:16 range:[-10000, 10000, normtime 1] type:#integer tooltip:"Animation export's end frame"
		)

		group "Folder"
		(
			button UI_OpenExportLocation "Export Location" width:94 pos:[14, 116] tooltip:"Open explorer window to <EXPORT> location"
			button UI_OpenSourceLocation "Source Location" width:94 pos:[116, 116] tooltip:"Open explorer window to <SOURCE> location"
		)

		on ui_rolloutgroup_main rolledup newState do
		(
			ResizeFloaterWindow ui_rolloutgroup_main
			if (PipeBoyInitialized) do ( ro_open_m = newState )
		)

		on UI_Export pressed do
		(
			if (TryExportCriteria == false) do ( return() )

			--Start export timer
			ExportTimerStart = timeStamp()

			print(" << Export >> ")

			UI_RefreshRollouts() --UI_Refresh rollout references

			cbf_updateui() --Update UI

			case GP_AssetTypeSelection of
			(
				--Geometry
				1:
				(
					local exportCollection = $*

					if (exportCollection.count == 0) do
					(
						messagebox "Scene is empty!" title:"Export error!"
						return()
					)

					if (ro_a == undefined) do (UI_RefreshRollouts())

					local combine = ro_a.UI_MeshGrouper.state
					local doLods = false --ro_a.UI_GenerateLODs.state--DISABLED

					PrepMesh collection:exportCollection groupMesh:combine --lod:doLods --lod_amount:0 --ro_a.UI_GenerateLODs_Amount

					local separate = if (ro_a.UI_SeparateMeshFiles.state == true) then ( separate = 3 ) else ( separate = 1 )

					ExportProcess exportType:separate collection:TMP_ExportGroup
				)

				--Rig
				3:
				(
					--Perform rig specific export sequence for all nodes
				)

				default:
				(
					messagebox "Current asset type is not set to Geometry or Rig!" title:"Invalid asset type!"
					return()
				)
			)
		)

		on UI_ExportSelection pressed do
		(
			if (TryExportCriteria trySelection:true == false) do ( return() )

			--Start export timer
			ExportTimerStart = timeStamp()

			print(" << Export Selection >> ")

			UI_RefreshRollouts() --UI_Refresh rollout references

			cbf_updateui() --Update UI

			case GP_AssetTypeSelection of
			(
				--Geometry
				1:
				(
					local exportCollection = selection as array

					if (ro_a == undefined) do (UI_RefreshRollouts())

					local combine = ro_a.UI_MeshGrouper.state
					local doLods = false --ro_a.UI_GenerateLODs.state--DISABLED

					PrepMesh collection:exportCollection groupMesh:combine --lod:doLods --lod_amount:0--ro_a.UI_GenerateLODs_Amount

					local separate = if (ro_a.UI_SeparateMeshFiles.state == true) then ( separate = 3 ) else ( separate = 1 )

					ExportProcess exportType:separate collection:TMP_ExportGroup
				)

				--Rig
				3:
				(
					--Perform rig specific export sequence for selected nodes
				)

				default:
				(
					messagebox "Current asset type is not set to Geometry or Rig!" title:"Invalid asset type!"
					return()
				)
			)
		)

		on UI_ExportAnimation pressed do
		(
			if (TryExportCriteria tryCharacter:true == false) do ( return() )

			--Start export timer
			ExportTimerStart = timeStamp()

			print(" << Export Animation >> ")

			UI_RefreshRollouts() --UI_Refresh rollout references

			cbf_updateui() --Update UI

			case GP_AssetTypeSelection of
			(
				--Animation
				2:
				(
					DisableSceneRedraw() --speed up processing

					--Store node selection
					local ExportSelection = GetCurrentSelection()

					local cNodes = undefined --Node collection of character rig
					local aNodes = undefined --Node collection of accessory rig

					--Pickbutton Character rig node
					local rootbone = ro_s.UI_PickCharacter.object

					--Aquire character root bone/ hierarchy to export
					if ((ro_s.UI_Rig_Character.selection > 1) or (rootbone != undefined)) then
					(
						--If we've selected a prefix for our character, use that
						if (ro_s.UI_Rig_Character.selection > 1) then
						(
							cNodes = GetPrefixObjects pre:ro_s.UI_Rig_Character.selected allowMeshes:true --XRef bones are geometry?
						)
						else
						(
							--If no prefix is applied, use the pick button's node
							--Backup try to grab node based on name on pickbutton
							if (rootbone == undefined OR isValidNode rootbone == false) do
							(
								rootbone = getNodeByName (ro_s.UI_PickCharacter.text as string)

								--If still null, exit the function
								if (rootbone == undefined OR isValidNode rootbone == false) do
								(
									EnableSceneRedraw()
									MessageBox "Can't find root bone, check project settings! (Case sensitive)" title:"NO ROOT!"
									return()
								)
							)

							--Grab related child bones
							local rootNodes = GetChildren obj:rootbone
							cNodes = rootNodes
						)
					)
					else
					(
						SortToHierarchy &ExportSelection

						cNodes = ExportSelection

						if (cNodes.count == 0) do
						(
							EnableSceneRedraw()
							MessageBox "Nothing selected, quitting export operation..." title:"Empty selection!"
							return()
						)
					)

					--print("[ Character rig nodes ]")
					--print(cNodes)

					--Prepare copy array for safe operation
					local copies = #()

					--Make copies of nodes to export for safer operation
					try
					(
						copies = CopyNodes collection:cNodes

						if (copies != undefined) then
						(
							--Remove prefixes from copied nodes
							StripPrefixes &copies

							--Print export node selection
							printc("[ Character Nodes ]")
							printc(copies)
						)
						else
						(
							print("Export Animation :: Failed to copy nodes to export!")
							return()
						)
					)
					catch
					(
						print("Export Animation :: Failed to copy nodes to export!")
						throw()
					)

					--Export list or single range
					try
					(
						--Expression for deciding wether or not to export using single range or sequence list
						local ExportSequenceList = (ro_s.UI_ExportSequences.state and ro_s.UI_List_Sequences.selection.count > 0)

						--Are we using the sequence list for export?
						if (ExportSequenceList == true) then
						(
							local selectedSequences = #()

							--Collect all selected sequences from sequence list
							for i in ro_s.UI_List_Sequences.selection do
							(
								if (TMP_SequenceArray[i] != undefined) do
								(
									append selectedSequences TMP_SequenceArray[i]
								)
							)

							printc("[ Selected Sequences ]")
							printc(selectedSequences)

							--Prepare to store export results to print after finishing operation
							free TMP_ExportResults

							--Go through and export each sequence in the list
							for s in selectedSequences do
							(
								--Try export accessory expression
								local TEA = (s.exportAccessory and ro_s.UI_ExportAccessory.state)

								ExportProcess collection:copies exportType:2 astart:s.range_start aend:s.range_end asequencename:s.sequenceName aexport:TEA batch:true
							)

							ExportTimerEnd = timeStamp()

							append TMP_ExportResults (">> Exported file(s) in :: " + (((ExportTimerEnd - ExportTimerStart) / 1000.0) as string) + "s")

							--Print export results
							for result in TMP_ExportResults do ( print(result) )
						)
						else
						(
							printc("No sequences selected, falling back to singular range export!")
							--If sequence list isn't used, we fall back to just using the set ranges

							ExportProcess collection:copies exportType:2 aexport:ro_s.UI_ExportAccessory.state batch:false
						)

						--Re-enable viewports after whole operation is done
						EnableSceneRedraw()

						--Clean up copied nodes from export process after operation is done
						for o in copies do ( if (isValidNode o) do ( delete o ) )
					)
					catch
					(
						--Try to clean up copied nodes from export process
						for o in copies do ( if (isValidNode o) do ( delete o ) )

						EnableSceneRedraw() --re-enable scene redrawing if error occurs

						--Wait with throwing error message until cleanup is performed
						throw()
					)
				)

				default:
				(
					messagebox "Current asset type is not set to animation!" title:"wrong asset type!"
					return()
				)
			)
		)

		on UI_OpenSourceLocation pressed do
		(
			if (TryExportCriteria() == false) do (return())

			--Get current file's path
			local pth = getFilenamePath(maxFilePath)

			--Compile string before running DOSCommand
			local cmnd = ("explorer " + pth) as string

			DOSCommand cmnd
		)

		on UI_OpenExportLocation pressed do
		(
			if (TryExportCriteria() == false) do (return())

			local pth = GetExportLocation()

			--Compile string before running DOSCommand
			local cmnd = ("explorer " + pth) as string

			DOSCommand cmnd
		)
    )

	rollout ui_rolloutgroup_sequence "ANIMATION"
    (
    	--Sequence settings
		group ""
		(
			button UI_EditSequences "Edit Sequences" pos:[12, 22] tooltip:"Opens <EDIT SEQUENCES> window"

			checkbox UI_ExportSequences "Use list" pos:[115, 22] tooltip:"Toggles animation export process to either export every selected sequence from sequence list, or only the selected frame range"
			checkbox UI_ExportAccessory "Accessory" pos:[115, 40] tooltip:"Toggles animation export process to include the selected accessory rig"

			multilistbox UI_List_Sequences "Sequence list" items:#("-----") pos:[12, 48] width:200 height:6

			dropdownlist UI_Rig_Character "Character" pos:[14, 152] width:90 tooltip:"Prefix used for character skeleton (overrides pick button if set)"
			dropdownlist UI_Rig_Accessory "Accessory" pos:[120, 152] width:90 tooltip:"Prefix used for accessory skeleton (overrides pick button if set)"

			pickbutton UI_PickCharacter "Undefined" pos:[14, 198] width:90 height:20 tooltip:"Direct node reference for character skeleton root bone (is overridden if a prefix is set)"
			pickbutton UI_PickAccessory "Undefined" pos:[120, 198] width:90 height:20 tooltip:"Direct node reference for accessory skeleton root bone (is overridden if a prefix is set)"
		)

		on UI_EditSequences pressed do
		(
			--Open floater from external file
			try(destroydialog PipeBoy_AnimSetup)catch()
			createdialog PipeBoy_AnimSetup style:#(#style_toolwindow, #style_sysmenu)

			cbf_updateui()
		)

		on UI_List_Sequences selected i do
		(
			cbf_updateui()
		)

		on UI_ExportSequences changed newState do
		(
			if (PipeBoyInitialized) do ( GP_UseSequenceList = newState )
		)

		on UI_ExportAccessory changed newState do
		(
			if (PipeBoyInitialized) do ( GP_ExportAccessory = newState )
		)

		on UI_Rig_Character selected newChar do
		(
			if (PipeBoyInitialized == true) do
			(
				GP_Character = newChar
			)
		)

		on UI_Rig_Accessory selected newAccessory do
		(
			if (PipeBoyInitialized == true) do
			(
				GP_Accessory = newAccessory
			)
		)

		on UI_PickCharacter picked obj do
		(
			if (obj != undefined) do
			(
				UI_PickCharacter.text = obj.name
				UI_PickCharacter.object = obj
			)
		)

		on UI_PickAccessory picked obj do
		(
			if (obj != undefined) do
			(
				UI_PickAccessory.text = obj.name
				UI_PickAccessory.object = obj
			)
		)

		on UI_PickCharacter rightclick do
		(
			UI_PickCharacter.text = "Undefined"
			UI_PickCharacter.object = undefined
		)

		on UI_PickAccessory rightclick do
		(
			UI_PickAccessory.text = "Undefined"
			UI_PickAccessory.object = undefined
		)

		on ui_rolloutgroup_sequence rolledup newState do
		(
			ResizeFloaterWindow ui_rolloutgroup_sequence
			if (PipeBoyInitialized) do ( ro_open_s = newState )
		)

		on ui_rolloutgroup_sequence open do
		(
			UI_ExportSequences.state = GP_UseSequenceList
			UI_ExportAccessory.state = GP_ExportAccessory

			cbf_updateui()
		)
    )

	rollout ui_rolloutgroup_asset "ASSET"
    (
		group "Asset Settings"
		(
			dropdownlist UI_AssetType "Asset Type" items:#("Geometry", "Animation") width:85 tooltip:"What type of asset we'll be exporting"

			checkbox UI_MeshGrouper "Mesh grouper" checked:false tooltip:"Use mesh grouper functionality upon export"
			--checkbox UI_GenerateLODs "Generate lods" checked:false
			--spinner UI_GenerateLODs_Amount "LODs" range:[1,6,2] type:#integer width:50 pos:[125, 92]

			checkbox UI_SeparateMeshFiles "Separate mesh files" checked:false tooltip:"Make each separated mesh node in scene get exported to its own file 'NOTE: Filename is based on mesh name!'"
			edittext UI_FileExtension "File name extension" tooltip:"Add this string after exported file names - eg: if sequence name is 'a_animation_01' and this string is '_test' then filename results to 'a_animation_01_test'"
		)

		on UI_AssetType selected newtype do
		(
			GP_AssetTypeSelection = newtype
		)

		on UI_MeshGrouper changed newState do
		(
			if (PipeBoyInitialized) do ( GP_MeshGrouper = newState )
		)

		--DISABLED
		--on UI_GenerateLODs changed newState do
		--(
		--	if (PipeBoyInitialized) do ( GP_GenerateLODs = newState )
		--)

		on UI_SeparateMeshFiles changed newState do
		(
			if (PipeBoyInitialized) do ( GP_SeparateMeshFiles = newState )
		)

		on ui_rolloutgroup_asset rolledup newState do
		(
			ResizeFloaterWindow ui_rolloutgroup_asset
			if (PipeBoyInitialized) do ( ro_open_a = newState )
		)

		on ui_rolloutgroup_asset open do
		(
			UI_AssetType.selection = GP_AssetTypeSelection

			UI_MeshGrouper.state = GP_MeshGrouper
			--UI_GenerateLODs.state = GP_GenerateLODs--DISABLED
			UI_SeparateMeshFiles.state = GP_SeparateMeshFiles
		)
    )

	rollout ui_rolloutgroup_project "PROJECT"
    (
		group "Project Settings"
		(
			dropdownlist UI_CurrentProject "Project" width:125 tooltip:"Currently selected project"
			button UI_EditProjectSettings "Edit" width:65 pos:[144,44] tooltip:"Opens project settings window"
		)

		group ""
		(
			button UI_Refresh "Refresh" width:80 align:#center tooltip:"Forces UI to refresh"
			checkbox UI_PrintMessages "Debug" checked:GP_PrintToConsole pos:[162,100] tooltip:"Enables printing of a bunch of debug messages in listener"
		)

		on ui_rolloutgroup_project open do
		(

		)

		on ui_rolloutgroup_project rolledup newState do
		(
			ResizeFloaterWindow ui_rolloutgroup_project
			if (PipeBoyInitialized) do ( ro_open_p = newState )
		)

		on UI_EditProjectSettings pressed do
		(
			--Open floater from external file
			try(destroydialog PipeBoy_ProjectSettings)catch()
			createdialog PipeBoy_ProjectSettings style:#(#style_toolwindow, #style_sysmenu)

			PipeBoy_ProjectSettings.TrySetNewProject(GP_CurrentProjectSelected)

			try
			(
				--Try setting the project setting window's project to currently selected one in main UI
				PipeBoy_ProjectSettings.TrySetNewProject(GP_CurrentProjectSelected)
			)catch()
		)

		on UI_CurrentProject selected newproject do
		(
			if (newproject != undefined) then
			(
				GP_CurrentProjectSelected = UI_CurrentProject.selection
				LoadProjectSettings()
			)
			else
			(
				MessageBox "Project seems to be missing!" title:"Missing project!"
				GP_CurrentProjectSelected = 1
			)

			cbf_updateui()

			UI_CurrentProject.items = TMP_ProjectArray
		)

		on UI_Refresh pressed do
		(
			cbf_updateui()

			UI_CurrentProject.items = TMP_ProjectArray
		)

		on UI_PrintMessages changed newstate do
		(
			GP_PrintToConsole = newstate
		)
    )

    --Init base rollout
	on PipeBoy open do
	(
		PipeBoyInitialized = false

		--fix initialized persistent variables
		if (GP_CurrentProjectSelected == undefined) do (GP_CurrentProjectSelected = 1)
		if (GP_AssetTypeSelection == undefined) do (GP_AssetTypeSelection = 1)
		if (GP_PrintToConsole == undefined) do (GP_PrintToConsole = false)
		if (GP_MeshGrouper == undefined) do (GP_MeshGrouper = false)
		--if (GP_GenerateLODs == undefined) do (GP_GenerateLODs = false)--DISABLED
		if (GP_SeparateMeshFiles == undefined) do (GP_SeparateMeshFiles = false)
		if (GP_UseSequenceList == undefined) do (GP_UseSequenceList = false)
		if (GP_ExportAccessory == undefined) do (GP_ExportAccessory = false)

		if (GP_Character == undefined or GP_Character == 0) do (GP_Character = 1)
		if (GP_Accessory == undefined or GP_Accessory == 0) do (GP_Accessory = 1)

		if (ro_open_m == undefined) do (ro_open_m = true)
		if (ro_open_s == undefined) do (ro_open_s = false)
		if (ro_open_a == undefined) do (ro_open_a = false)
		if (ro_open_p == undefined) do (ro_open_p = false)

		--Force print
		--GP_PrintToConsole = true

		--Add sub rollouts
		addsubrollout ui_base ui_rolloutgroup_main
		addsubrollout ui_base ui_rolloutgroup_sequence
		addsubrollout ui_base ui_rolloutgroup_asset
		addsubrollout ui_base ui_rolloutgroup_project

		--Cache global references to rollouts
		UI_RefreshRollouts()

		--Set main rollout heights
		PipeBoy.height = PipeBoy_FloaterWindowHeight
		PipeBoySub.height = PipeBoy.height --PipeBoy_FloaterWindowHeight

		--Open or close rollouts from memory?
		if ((ro_m != undefined) and (ro_s != undefined) and (ro_a != undefined) and (ro_p != undefined)) do
		(
			if ((classOf ro_open_m == booleanclass) and (classOf ro_open_s == booleanclass) and (classOf ro_open_a == booleanclass) and (classOf ro_open_p == booleanclass)) then
			(
				ro_m.open = ro_open_m
				ro_s.open = ro_open_s
				ro_a.open = ro_open_a
				ro_p.open = ro_open_p
			)
			else
			(
				ro_m.open = true
				ro_s.open = false
				ro_a.open = false
				ro_p.open = false
			)
		)

		--Setup interface data
		LoadProjectSettings()

		--Try and load sequences
		LoadSequences()

		--Set current selected project from scene memory
		ro_p.UI_CurrentProject.items = TMP_ProjectArray
		ro_p.UI_CurrentProject.selection = GP_CurrentProjectSelected

		--Set debug print UI to globally persistent variable
		ro_p.UI_PrintMessages.checked = GP_PrintToConsole

		--Set asset type selection from scene memory
		ro_a.UI_AssetType.selection = GP_AssetTypeSelection

		--Set export rigs from scene memory
		ro_s.UI_Rig_Character.selection = GP_Character
		ro_s.UI_Rig_Accessory.selection = GP_Accessory

		--print("Char: " + GP_Character as string)
		--print("Acc: " + GP_Accessory as string)

		--Allow persistent vars to be set and UI updates to happen
		PipeBoyInitialized = true

		--Force an initial UI update
		cbf_updateui()

		--Add callbacks for opening a new file while PipeBoy is open to update relevant menu items
		callbacks.removescripts #filepostopen  id:#cb_updateui
		callbacks.addscript #filepostopen "cbf_updateui_fn()" id:#cb_updateui

		--Just to be safe, enable scene redraw
		EnableSceneRedraw()
		renderscenedialog.update()

		print("Hey, it's PipeBoy!")
	)

	--Destruct callbacks when closed
	on PipeBoy close do
	(
		callbacks.removescripts #filepostopen  id:#cb_updateui
	)
)
)

--Launch floater AFTER we've figured out rollout heights
try(destroydialog PipeBoy)catch()
createdialog PipeBoy style:#(#style_toolwindow, #style_sysmenu) pos:[1100,150] height:500 width:235
