/*////////////////////////////////////////////////
pipeboy is a pipeline tool that strives to improve
general workflows for game-related asset creation.
////////////////////////////////////////////////*/

--start pipeboy--
(--start local scope
include "$userscripts\maxboy\maxboy_functions.ms"

--initialize persistent globals
persistent global currentprojectselected
persistent global AssetTypeSelection
persistent global printtoconsole

--Global rollout references
global ro_m
global ro_s
global ro_a
global ro_p

--remember which panels are open
persistent global ro_open_m
persistent global ro_open_s
persistent global ro_open_a
persistent global ro_open_p

--misc menu settings memory
persistent global p_meshGrouper
persistent global p_generateLods
persistent global p_separateMeshFiles
persistent global p_useSequenceList
persistent global p_exportAccessory

--initialize globals
global gname = (getfilenamefile  maxfilename)
global pipeboy --rollout class handle
global pipeboysettings --pipeboy settings file
global pipeboyanimsetup --pipeboy animation setup file
global pbs --pipeboy settings .ini file handle
global allowStorePersistance --Delay setting persistent vars

--Temp arrays
global exportgroup = #()
global exportResults = #()
global cleangroup = #()
global projectarray = #()
global sequencearray = #()

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
	s_ac_LockRootDepth, --booleanClass

	s_ac_FilePrefix,	--String
	s_ac_FileSuffix,	--String
	s_ac_RemoveFilePre,	--Integer
	s_ac_RemoveFileSuf  --Integer
)

--local sequence struct
struct sequence
(
	sequenceName		= "null",   --string
	exportAccessory		= false, 	--booleanclass
	range_start 		= 0, 		--integer
	range_end 			= 1 		--integer
)

--initialize local settings "container" to easily store and update for later
global ls = localsettings()


--loads project variables
fn loadvariables =
(
	--setup which project to load from file
	--print("pbs: " + pbs)
	tempprojectarray = getinisetting pbs "maindata" "g_projects"
	global projectarray = execute tempprojectarray

	if (currentprojectselected == undefined or currentprojectselected == 0) then
		t_selectproject = 1
		else
		t_selectproject = currentprojectselected

	global currentprojectselected = t_selectproject

	if (projectarray[t_selectproject] != undefined) then
	(
		local pro = (projectarray[t_selectproject] as string)

		global p_projectroot 		= (getinisetting pbs pro "p_projectroot")
		global p_projectsource 		= (getinisetting pbs pro "p_projectsource")
		global p_projectasset 		= (getinisetting pbs pro "p_projectasset")

		global s_engine 			= (getinisetting pbs pro "s_engine") as integer
		global s_importfromraw 		= (getinisetting pbs pro "s_importfromraw") as booleanclass
		global s_forwardaxis 		= (getinisetting pbs pro "s_forwardaxis") as integer
		global s_meshgroupprefix 	= (getinisetting pbs pro "s_meshgroupprefix")

		global s_boneprefix 		= (getinisetting pbs pro "s_boneprefix")
		global s_boneroot 			= (getinisetting pbs pro "s_boneroot")
		global s_alignprefix 		= (getinisetting pbs pro "s_alignprefix")

		global s_ac_folder 			= (getinisetting pbs pro "s_ac_folder")
		global s_ac_prefix 			= (getinisetting pbs pro "s_ac_prefix")
		global s_ac_findintelligent = (getinisetting pbs pro "s_ac_findintelligent") as booleanclass
		global s_ac_lockroot		= (getinisetting pbs pro "s_ac_lockroot") as booleanclass
		global s_ac_lockrootdepth 	= (getinisetting pbs pro "s_ac_lockrootdepth") as integer

		global s_ac_fileprefix 		= (getinisetting pbs pro "s_ac_fileprefix")
		global s_ac_filesuffix 		= (getinisetting pbs pro "s_ac_filesuffix")
		global s_ac_removefilepre 	= (getinisetting pbs pro "s_ac_removefilepre") as integer
		global s_ac_removefilesuf 	= (getinisetting pbs pro "s_ac_removefilesuf") as integer

		printc("loaded project: " + pro)
	)
	else
	(
		messagebox "project seems to be missing!" title:"missing project!"
	)
)

--load from .boi file
fn loadsequences =
(
	--call garbage collection to avoid i/o issues
	gc()

	if (maxfilename == "") do
	(
		printc("Won't attempt sequence load - scene is unsaved")
		return()
	)

	--remove file name's extension
	local filteredname = replace (maxfilename as string) (maxfilename.count - 3) 4 ""

	--construct search path
	local relativepath = ((getscriptlocation (getthisscriptfilename() as string) "pipeboy") + "\\animsetup\\" + filteredname + ".boi")

	--convert to valid search path
	local filepath = converttopath relativepath

	if (doesfileexist filepath == false) do
	(
		printc("no file to load from @ " + (filepath as string))
		return()
	)

	local ofile = openfile filepath mode:"r"

	if (ofile != undefined) then
	(
		--print("loading sequences from >> " + relativepath)
		sequencearray = #()

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

				append sequencearray loadsequence
			)
		) while (searchresult != undefined)

		close ofile

		--print("sequence array >> " + sequencearray as string)
		if (sequencearray.count == 0) then
		(
			printc("Load Sequences :: [ Found (.boi) file, but found no sequences! ]")
		)
		else
		(
			printc("Load Sequences :: [ Loaded (" + (sequencearray.count as string) + ") sequences from file ]")
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
	--Load related settings
	loadvariables()

	--Load related scene sequence list
	loadsequences()

	if (ro_m != undefined) then
	(
		ro_m.anim_range_start.value = normtime 0
		ro_m.anim_range_end.value = normtime 1
	)
	else
	(
		print("UpdateUI :: rollout main is undefined!")
	)

	if (ro_s != undefined) then
	(
		local itemList = #()

		--Update sequence list UI
		for s in sequencearray do
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

		ro_s.list_sequences.items = itemList

		--Update prefix lists
		local searchSelection = $*

		local prefixes = #("---")

		for o in searchSelection do
		(
			local n = o.name

			if (n != undefined) do
			(
				if (matchPattern n pattern:("*:*")) do
				(
					local i = findString n ":"
					local pre = (substring n 1 i)

					local tryFindPrefix = findItem prefixes pre

					if (tryFindPrefix == 0) do
					(
						append prefixes pre
					)
				)
			)
		)

		ro_s.rigCharacter.items = prefixes
		ro_s.rigAccessory.items = prefixes
	)
	else
	(
		print("UpdateUI :: rollout sequence is undefined!")
	)

	printc("updated ui!")
) global cbf_updateui_fn = cbf_updateui --store as global varaible


fn lodgenerator &obj lods =
(
	clearselection()
	disablesceneredraw()

	try
	(
	with undo off
	(
		for lodobj in obj do
		(
			try
			(
				local removeobjfromexport = finditem exportgroup lodobj
				deleteitem exportgroup removeobjfromexport
			)
			catch
			(
				print("couldn't delete object from export group!")
			)


			local safelodcopy = CopyNodes collection:lodobj
			append cleangroup safelodcopy

			templodobj = safelodcopy[1]
			templodobj.name = ((trimright lodobj.name "0123456789") + "_lod0")

			append exportgroup templodobj

			for i = 1 to lods do
			(
				safelodstepcopy = CloneNodes collection:templodobj

				append cleangroup safelodstepcopy
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

				append exportgroup lodstepobject

				--free lodstepobject
			)

			--free templodobj
		)
	)
	)
	catch(enablesceneredraw())

	enablesceneredraw()
	clearselection()
)

fn GetExportLocation =
(
	local pro = projectarray[currentprojectselected] as string

	--Trim full file path name with project source path
	local p_length = ((getinisetting pbs pro "p_projectsource").count)
	local p_subpath = replace (maxfilepath as string) 1 (p_length) ""

	--Build final path to file export location (Source or project location)
	local p_fileexportpath = p_fileexportpath = pathconfig.appendpath p_projectroot p_subpath

	if (s_importfromraw) do
	(
		p_fileexportpath = (maxfilepath as string)
	)

	--Return resulting path
	return p_fileexportpath
)

fn PostExportCleanup =
(
	if (cleangroup != undefined) do
	(
		for o in cleangroup do ( if (isValidnode o) do ( delete o ) )
		free cleangroup
	)

	if (safecopies != undefined) do
	(
		for o in safecopies do ( if (isValidnode o) do ( delete o ) )
		free safecopies
	)

	if (exportgroup != undefined) do
	(
		for o in exportgroup do ( if (isValidnode o) do ( delete o ) )
		free exportgroup
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
		local cSel = ro_s.rigCharacter.selection
		local aSel = ro_s.rigAccessory.selection

		if (cSel == aSel) do
		(
			messagebox "Character and Accessory rigs are marked as the same!" title:"Export Error!"
			return false
		)
	)

	return true
)

--Dependent include (Sub-Floater)
include "$userscripts\maxboy\pipeboy_animsetup.ms"

--Base UI height
local baseHeight = 94

rollout pipeboy "PipeBoy"
(
	--construct base ui "frame" for rollout windows
	subrollout ui_base width:235 height:baseHeight pos:[0,0]

	--window resize function for rollouts [ override ]
	fn resizewindow ttarget trollout tstate =
	(
		--local baseOffset = -20

	    if (tstate == true) then
	    (
			ui_base.height += trollout.height
			ttarget.height += trollout.height
	    )
	    else
	    (
			ui_base.height -= trollout.height
			ttarget.height -= trollout.height
	    )

	    cbf_updateui()
	)

	fn refreshrollouts =
	(
		ro_m = pipeboy.ui_rolloutgroup_main
		ro_s = pipeboy.ui_rolloutgroup_sequence
		ro_a = pipeboy.ui_rolloutgroup_asset
		ro_p = pipeboy.ui_rolloutgroup_project
	)

	fn rotatepivotonlyengine obj =
	(
		/*
		1 = x-forward
		2 = - x-forward
		3 = y-forward
		4 = - y-forward
		*/

		local rotvalinv --set up local rotation variable

		case s_engine of
		(
			--local rotvalinv = case s_forwardaxis of

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

	fn ExportProcess collection: exportType:1 astart: aend: asequencename: aexport:false overrideredraw:false delayPrint:false =
	(
		local exportCollection = #()

		--Do this rather than supply default to have it autimatically pick exportgroup if unsupplied
		if (collection == unsupplied) then ( exportCollection = exportgroup ) else ( exportCollection = collection)

		local r_start = ro_m.anim_range_start.value
		local r_end = ro_m.anim_range_end.value

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
			printc("path folder not found, creating folder.")
			makedir p_fileexportpath
		)

		--Filename-based naming as a baseline
		local fileexportname = (p_fileexportpath + gname + ro_a.fileextension.text + ".fbx") as string

		--Only select defined collection for export
		clearSelection()
		--select exportCollection
		selectmore exportCollection

		if (delayPrint == false) do ( printc(selection) )

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
				exportfile (fileexportname) #noprompt selectedonly:true using:theplugin

				if (delayPrint == false) then ( print("Exported at >> " + fileexportname as string) ) else ( append exportResults ("Exported at >> " + fileexportname) )
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
					fileexportname = (p_fileexportpath + (asequencename as string) + ro_a.fileextension.text + ".fbx") as string
				)

				--[ Export accessory ]--
				if (aexport == true) do
				(
					local aSel = ro_s.rigAccessory.selection

					local accessoryCopies = undefined

					if (aSel != 0 and aSel != 1) then
					(
						local accessoryChildren = getPrefixObjects pre:ro_s.rigAccessory.selected
						accessoryCopies = CopyNodes collection:accessoryChildren
					)
					else
					(
						--local accessory = LocateAccessory pre:s_ac_prefix
						local accessory = ro_s.pickAccessory.object

						if (isValidNode accessory) do
						(
							local accessoryChildren = getChildren obj:accessory
							accessoryCopies = CopyNodes collection:accessoryChildren
						)
					)

					if (accessoryCopies != undefined) then
					(
						stripPrefixes(accessoryCopies)

						printc("[ Accessory Nodes ]")
						printc(accessoryCopies)

						if (s_ac_lockroot == true) do
						(
							--Start with baking down rig bones to release constraints
							BakeKeys collection:accessoryCopies rs:r_start re:r_end

							--Set up root constraints
							local rootLocker = point name:"RootLocker" size:20

							pc = Position_Constraint()
					        oc = Orientation_Constraint()

					        pcc = pc.constraints
					        pcc.appendTarget rootLocker 100.0

					        occ = oc.constraints
					        occ.appendTarget rootLocker 100.0

					        --Apply constraints in certain depth in rig
					        for i = 1 to s_ac_LockRootDepth do
					        (
								accessoryCopies[i].pos.controller = pc
								accessoryCopies[i].rotation.controller = oc
					        )
						)

						--Only select defined collection for export
						clearSelection()
						selectmore accessoryCopies

						local accessoryexportname = ""
						local adjustedname = gname

						if (asequencename != unsupplied) do (adjustedname = (asequencename as string))

						local accessoryname = replace adjustedname 1 s_ac_removefilepre s_ac_fileprefix
						accessoryname = replace accessoryname (accessoryname.count - s_ac_removefilesuf) s_ac_removefilesuf s_ac_filesuffix

						local accessoryfolder =  ((s_ac_folder as string) + "\\")

						accessoryexportname = (p_fileexportpath + accessoryfolder + accessoryname + ro_a.fileextension.text + ".fbx") as string

						--Make missing destination folders in windows if they're missing
						if (not doesfileexist (p_fileexportpath + accessoryfolder) or not getfileattribute (p_fileexportpath + accessoryfolder) #directory) do
						(
							--path folder not found, create folder
							printc("Accessory folder not found, creating folder.")
							makedir (p_fileexportpath + accessoryfolder)
						)

						exportfile (accessoryexportname) #noprompt selectedonly:true using:theplugin

						for o in accessoryCopies do
						(
							if (isValidNode o) do
							(
								delete o
							)
						)

						if (isValidnode rootLocker) do (delete rootLocker)

						if (delayPrint == false) then ( print("Exported accessory at >> " + accessoryexportname) ) else ( append exportResults ("Exported accessory at >> " + accessoryexportname) )
					)
					else
					(
						print("Export :: No accessory found!")
					)
				)

				--Regrab selection
				clearSelection()
				selectmore exportCollection

				--Perform export operation
				exportfile (fileexportname) #noprompt selectedonly:true using:theplugin

				--[ Finish up export sequence]--
				animationrange = tempinterval

				if (delayPrint == false) then ( print("Exported at >> " + fileexportname as string) ) else ( append exportResults ("Exported at >> " + fileexportname) )
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
							local convexSearchString  = ("UCX_" + e_mesh.name + "*") as string
							local boxSearchString     = ("UBX_" + e_mesh.name + "*") as string
							local capsuleSearchString = ("UCP_" + e_mesh.name + "*") as string
							local sphereSearchString  = ("USP_" + e_mesh.name + "*") as string

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
							local MeshFileName = (p_fileexportpath + e_mesh.name + ro_a.fileextension.text + ".fbx") as string

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
									MeshFileName = (folderPath + e_mesh.name + ro_a.fileextension.text + ".fbx") as string
								)
							)

							exportfile (MeshFileName) #noprompt selectedonly:true using:theplugin

							print("Exported file :: " + MeshFileName)
						)
					)
				)
			)
		)

		PostExportCleanup()

		clearselection()

		if (overrideredraw == false) do ( enablesceneredraw() )
	)

	fn PrepMesh collection:$* groupMesh:false lod:false lod_amount:3 =
	(
		refreshrollouts()

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

			local removeobjectsselection = getChildren obj:excludeobject

			for i = 1 to removeobjectsselection.count do
			(
				local findque = finditem objectselection removeobjectsselection[i]

				if (findque != 0) do
					deleteitem objectselection findque
			)
		)

		global grouparray = #()

		free cleangroup
		free exportgroup

		try
		(
			disablesceneredraw()

			with undo off
			(
				--create root export object for axis conversion
				local exportparent = point size:500 name:"exportparent"
				rotatepivotonlyengine(exportparent)
				freezetransforms(exportparent)

				append exportgroup exportparent
				append cleangroup exportparent

				--clone export objects for non-destructive processing
				local safecopies = CopyNodes collection:objectselection

				--append cleangroup safecopies --PENDING DEPRECATION
				join cleangroup safecopies

				--make all instances in selection unique (will be ignored otherwise)
				instancemgr.makeobjectsunique safecopies #individual

				if (s_meshgroupprefix == undefined) do (s_meshgroupprefix = "g_")

				--assume there are no mesh group objects in scene
				local validgroupobjects = false

				--collect mesh groups in selection
				for obj in safecopies do
				(
					if (matchpattern obj.name pattern:(s_meshgroupprefix + "*") == true) do
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

						local meshSearchCollection = getChildren obj:g
						local combininggroup = filterformeshes(meshSearchCollection)

						printc("\ngroup objects {")
						printc(combininggroup as array)

						--local groupname = replace (trimright (g.name as string) "0123456789") 1 s_meshgroupprefix.count ""
						local groupname = replace (g.name as string) 1 s_meshgroupprefix.count ""

						local groupparent = point size:100 name:(("g_" + groupname) as string)
						rotatepivotonlyengine(groupparent)

						append exportgroup groupparent
						append cleangroup groupparent

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
						rotatepivotonlyengine(combinedmesh)

						--add combined object to group
						append exportgroup combinedmesh
						append cleangroup combinedmesh
					)
				)
				else
				(
					--regular export selection
					local combininggroup = filterformeshes(safecopies)

					for c in combininggroup do
					(
						collapsestack c
						convertto c editable_poly

						local currentparent = c.parent
						c.parent = undefined

						--Fix parenting
						if (currentparent == undefined) then (c.parent = exportparent) else (c.parent = currentparent)

						--Fix pivot orientation to engine specifics
						rotatepivotonlyengine(c)

						append exportgroup c
						--append cleangroup c
					)
				)
			)
		)
		catch
		(
			enablesceneredraw()

			PostExportCleanup()

			messagebox "Something went wrong during mesh cooking!" title:"error"

			throw()
		)

		if (lod == true) do
		(
			local lodmeshsgroups = filterformeshes exportgroup
			lodgenerator lodmeshsgroups lod_amount
		)

		--done!
		printc("\n Operation done!")
		printc("[ Export Group ]")
		printc(exportgroup)

		rotate exportparent (eulerangles 0 0 -90)

		--Prep is done and applied to the export group, returning to called location
		return()
	)

	rollout ui_rolloutgroup_main "EXPORT"
    (
		group "General"
		(
			button Export "Export" width:94 pos:[14, 22]
			button ExportSelection "Export Selection" width:94 pos:[116, 22]
		)

		group "Animation"
		(
			button ExportAnimation "Export Animation" width:94 pos:[14, 70]

			spinner anim_range_start "" pos:[115, 73] width:42 height:16 range:[-10000, 10000, normtime 0] type:#integer
			spinner anim_range_end  "to " pos:[115+54, 73] width:42 height:16 range:[-10000, 10000, normtime 1] type:#integer
		)

		group "Folder"
		(
			button OpenExportLocation "Export Location" width:94 pos:[14, 116]
			button OpenSourceLocation "Source Location" width:94 pos:[116, 116]
		)

		on ui_rolloutgroup_main rolledup state do
		(
			resizewindow pipeboy ui_rolloutgroup_main state
			if (allowStorePersistance) do ( ro_open_m = state )
		)

		on Export pressed do
		(
			if (TryExportCriteria == false) do ( return() )

			print(" << Export >> ")

			loadvariables() -- double check saved variables
			refreshrollouts() --same for rollouts

			case AssetTypeSelection of
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

					if (ro_a == undefined) do (refreshrollouts())

					local combine = ro_a.meshgrouper.state
					local doLods = false --ro_a.generatelods.state--DISABLED

					PrepMesh collection:exportCollection groupMesh:combine --lod:doLods --lod_amount:0 --ro_a.lodsamount

					local separate = if (ro_a.separateMeshFiles.state == true) then ( separate = 3 ) else ( separate = 1 )

					ExportProcess exportType:separate collection:exportgroup
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

		on ExportSelection pressed do
		(
			if (TryExportCriteria trySelection:true == false) do ( return() )

			print(" << Export selection >> ")

			loadvariables() -- double check saved variables
			refreshrollouts() -- same for rollouts

			case AssetTypeSelection of
			(
				--Geometry
				1:
				(
					local exportCollection = selection as array

					if (ro_a == undefined) do (refreshrollouts())

					local combine = ro_a.meshgrouper.state
					local doLods = false --ro_a.generatelods.state--DISABLED

					PrepMesh collection:exportCollection groupMesh:combine --lod:doLods --lod_amount:0--ro_a.lodsamount

					local separate = if (ro_a.separateMeshFiles.state == true) then ( separate = 3 ) else ( separate = 1 )

					ExportProcess exportType:separate collection:exportgroup
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

		on ExportAnimation pressed do
		(
			if (TryExportCriteria tryCharacter:true == false) do ( return() )

			print(" << Export Animation >> ")

			loadvariables() -- double check saved variables
			refreshrollouts() --same for rollouts

			case AssetTypeSelection of
			(
				--Animation
				2:
				(
					local cNodes = undefined --Node collection of character rig
					local aNodes = undefined --Node collection of accessory rig

					if (selection.count == 0) then
					(
						if (ro_s.rigCharacter.selection != 1) then
						(
							cNodes = getPrefixObjects pre:ro_s.rigCharacter.selected allowMeshes:true --XRef bones are geometry?
						)
						else
						(
							--local rootbone = getnodebyname (s_boneroot as string) ignorecase:false
							local rootbone = ro_s.pickCharacter.object

							--Backup try to grab node based on name on pickbutton
							if (rootbone == undefined OR isValidNode rootbone == false) do
							(
								rootbone = getNodeByName (ro_s.pickCharacter.text as string)

								--If still null, exit the function
								if (rootbone == undefined OR isValidNode rootbone == false) do
								(
									enablesceneredraw()
									messagebox "Can't find root bone, check project settings! (Case sensitive)" title:"NO ROOT!"
									return()
								)
							)

							local rootNodes = getChildren obj:rootbone
							cNodes = rootNodes
						)
					)
					else
					(
						local ta = getCurrentSelection()
						local ti = #()

						sortToHierarchy &ta &ti

						local tryGetRoot = ta[1]

						if (isValidNode tryGetRoot == true) then
						(
							local rootNodes = getChildren obj:tryGetRoot
							cNodes = rootNodes
						)
						else
						(
							enablesceneredraw()
							messagebox "Can't find root bone, check project settings! (Case sensitive)" title:"NO ROOT!"
							return()
						)
					)

					-- debug print selection
					--print("[ Character rig nodes ]")
					--print(cNodes)

					--Prepare copy array for safe operation
					local copies = #()

					try
					(
						DisableSceneRedraw() --speed up processing

						--Make copies of bones to export for safer operation
						copies = CopyNodes collection:cNodes

						--Remove prefixes from copied nodes
						stripPrefixes(copies)

						--Print export node selection
						printc("[ Nodes ]")
						printc(copies)

						if (ro_s.exportsequences.state == true) then
						(
							local selectedSequences = #()

							for i in ro_s.list_sequences.selection do
							(
								if (sequencearray[i] != undefined) do
								(
									append selectedSequences sequencearray[i]
								)
							)

							printc("[ Selected Sequences ]")
							printc(selectedSequences)

							--Prepare to store export results to print after finishing operation
							free exportResults

							for s in selectedSequences do
							(
								--Try export accessory
								local tea = (s.exportAccessory and ro_s.exportaccessory.state)

								ExportProcess collection:copies exportType:2 astart:s.range_start aend:s.range_end asequencename:s.sequenceName aexport:tea overrideredraw:true delayPrint:true
							)

							EnableSceneRedraw()

							--Print export results
							for result in exportResults do ( print(result) )
						)
						else
						(
							ExportProcess collection:copies exportType:2 aexport:ro_s.exportaccessory.state
						)

						--Clean up copied nodes from export process after operation is done
						for o in copies do ( if (isValidNode o) do ( delete o ) )
					)
					catch
					(
						--Try to clean up copied nodes from export process
						for o in copies do ( if (isValidNode o) do ( delete o ) )

						enablesceneredraw() --re-enable scene redrawing if error occurs

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

		on OpenSourceLocation pressed do
		(
			if (TryExportCriteria() == false) do (return())

			--Get current file's path
			local pth = getFilenamePath(maxFilePath)

			--Compile string before running DOSCommand
			local cmnd = ("explorer " + pth) as string

			DOSCommand cmnd
		)

		on OpenExportLocation pressed do
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
			button editsequences "Edit Sequences" pos:[12, 22]

			checkbox exportsequences "Use list" pos:[115, 22]
			checkbox exportaccessory "Accessory" pos:[115, 40]

			multilistbox list_sequences "Sequence list" items:#("-----") pos:[12, 48] width:200 height:6

			dropdownlist rigCharacter "Character" pos:[14, 152] width:90 tooltip:"Prefix used for character skeleton (overrides pick button if set)"
			dropdownlist rigAccessory "Accessory" pos:[120, 152] width:90 tooltip:"Prefix used for accessory skeleton (overrides pick button if set)"

			pickbutton pickCharacter "Undefined" pos:[14, 198] width:90 height:20 tooltip:"Direct node reference for character skeleton root bone (is overridden if a prefix is set)"
			pickbutton pickAccessory "Undefined" pos:[120, 198] width:90 height:20 tooltip:"Direct node reference for accessory skeleton root bone (is overridden if a prefix is set)"
		)

		on editsequences pressed do
		(
			--Open floater from external file
			try(destroydialog PipeBoy_AnimSetup)catch()
			createdialog PipeBoy_AnimSetup style:#(#style_toolwindow, #style_sysmenu)

			cbf_updateui()
		)

		on list_sequences selected i do
		(
			cbf_updateui()
		)

		on pickCharacter picked obj do
		(
			if (obj != undefined) do
			(
				pickCharacter.text = obj.name
				pickCharacter.object = obj
			)
		)

		on pickAccessory picked obj do
		(
			if (obj != undefined) do
			(
				pickAccessory.text = obj.name
				pickAccessory.object = obj
			)
		)

		on pickCharacter rightclick do
		(
			pickCharacter.text = "Undefined"
			pickCharacter.object = undefined
		)

		on pickAccessory rightclick do
		(
			pickAccessory.text = "Undefined"
			pickAccessory.object = undefined
		)

		on exportsequences changed newState do
		(
			if (allowStorePersistance) do ( p_useSequenceList = newState )
		)

		on exportaccessory changed newState do
		(
			if (allowStorePersistance) do ( p_exportAccessory = newState )
		)

		on ui_rolloutgroup_sequence rolledup state do
		(
			resizewindow pipeboy ui_rolloutgroup_sequence state
			if (allowStorePersistance) do ( ro_open_s = state )
		)

		on ui_rolloutgroup_sequence open do
		(
			exportsequences.state = p_useSequenceList
			exportaccessory.state = p_exportAccessory

			cbf_updateui()
		)
    )

	rollout ui_rolloutgroup_asset "ASSET"
    (
		group "Asset Settings"
		(
			dropdownlist istype "Asset Type" items:#("Geometry", "Animation") width:85

			checkbox meshgrouper "Mesh grouper" checked:false
			--checkbox generatelods "Generate lods" checked:false
			--spinner lodsamount "LODs" range:[1,6,2] type:#integer width:50 pos:[125, 92]

			checkbox separateMeshFiles "Separate mesh files" checked:false tooltip:"Make each separated mesh node in scene get exported with its own file (Filename based on mesh name!)"
			edittext fileextension "File name extension"
		)

		on istype selected newtype do
		(
			AssetTypeSelection = newtype
		)

		on meshgrouper changed newState do
		(
			if (allowStorePersistance) do ( p_meshGrouper = newState )
		)

		/*DISABLED
		on generatelods changed newState do
		(
			if (allowStorePersistance) do ( p_generateLods = newState )
		)
		*/

		on separateMeshFiles changed newState do
		(
			if (allowStorePersistance) do ( p_separateMeshFiles = newState )
		)

		on ui_rolloutgroup_asset rolledup state do
		(
			resizewindow pipeboy ui_rolloutgroup_asset state
			if (allowStorePersistance) do ( ro_open_a = state )
		)

		on ui_rolloutgroup_asset open do
		(
			istype.selection = AssetTypeSelection

			meshgrouper.state = p_meshGrouper
			--generatelods.state = p_generateLods--DISABLED
			separateMeshFiles.state = p_separateMeshFiles
		)
    )

	rollout ui_rolloutgroup_project "PROJECT"
    (
		group "Project Settings"
		(
			dropdownlist currentproject "Project" width:125
			button editprojectsettings "Edit" width:65 pos:[144,44]
		)

		group ""
		(
			button refresh "Refresh" width:80 align:#center
			checkbox printmessages "Debug" checked:printtoconsole pos:[162,100]
		)

		on ui_rolloutgroup_project open do
		(

		)

		on ui_rolloutgroup_project rolledup state do
		(
			resizewindow pipeboy ui_rolloutgroup_project state

			if (allowStorePersistance) do ( ro_open_p = state )
		)

		on editprojectsettings pressed do
		(
			filein pipeboysettings
		)

		on currentproject selected newproject do
		(
			if (newproject != undefined) then
			(
				currentprojectselected = currentproject.selection
				loadvariables()
			)
			else
			(
				messagebox "project seems to be missing!" title:"missing project!"
				currentprojectselected = 1
			)
		)

		on refresh pressed do
		(
			cbf_updateui()

			currentproject.items = projectarray
		)

		on printmessages changed newstate do
		(
			printtoconsole = newstate
		)
    )

    --Init base rollout
	on pipeboy open do
	(
		allowStorePersistance = false

		--fix initialized persistent variables
		if (currentprojectselected == undefined) do (currentprojectselected = 1)
		if (AssetTypeSelection == undefined) do (AssetTypeSelection = 1)
		if (printtoconsole == undefined) do (printtoconsole = false)
		if (p_meshGrouper == undefined) do (p_meshGrouper = false)
		--if (p_generateLods == undefined) do (p_generateLods = false)--DISABLED
		if (p_separateMeshFiles == undefined) do (p_separateMeshFiles = false)
		if (p_useSequenceList == undefined) do (p_useSequenceList = false)
		if (p_exportAccessory == undefined) do (p_exportAccessory = false)
		if (ro_open_m == undefined) do (ro_open_m = true)
		if (ro_open_s == undefined) do (ro_open_s = false)
		if (ro_open_a == undefined) do (ro_open_a = false)
		if (ro_open_p == undefined) do (ro_open_p = false)

		--Add sub rollouts
		addsubrollout ui_base ui_rolloutgroup_main
		addsubrollout ui_base ui_rolloutgroup_sequence
		addsubrollout ui_base ui_rolloutgroup_asset
		addsubrollout ui_base ui_rolloutgroup_project

		--Cache global references to rollouts
		refreshrollouts()

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
		--Initialize script references
		pbs = (pathconfig.getdir #userscripts) + ( "\\maxboy\\pipeboy_settings.ini")
		pipeboysettings = (pathconfig.getdir #userscripts) + ( "\\maxboy\\pipeboy_projectsettings.ms")
		pipeboyanimsetup = (pathconfig.getdir #userscripts) + ( "\\maxboy\\pipeboy_animsetup.ms")

		--Setup interface data
		loadvariables()

		--Try and load sequences
		loadsequences()

		--Set current selected project from scene memory
		ro_p.currentproject.items = projectarray
		ro_p.currentproject.selection = currentprojectselected

		--Set asset type selection from scene memory
		ro_a.istype.selection = AssetTypeSelection

		allowStorePersistance = true

		--Force a UI update
		cbf_updateui()

		--Add callbacks for opening a new file while pipeboy is open to update relevant menu items
		callbacks.removescripts #filepostopen  id:#cb_updateui
		callbacks.addscript #filepostopen "cbf_updateui_fn()" id:#cb_updateui

		--Just to be safe, enable scene redraw
		enablesceneredraw()
		renderscenedialog.update()
	)

	--Destruct callbacks when closed
	on pipeboy close do
	(
		callbacks.removescripts #filepostopen  id:#cb_updateui
	)
)

try(destroydialog pipeboy)catch()
createdialog pipeboy style:#(#style_toolwindow, #style_sysmenu) pos:[1100,150] height:baseHeight width:235
)
