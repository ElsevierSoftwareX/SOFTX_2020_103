
#region # * prepare to create expansion, retrofitting and capacity variables

# ! dimensions for expansion variables
function prepareExpansion!(prepTech_dic::Dict{Symbol,NamedTuple},tsYear_dic::Dict{Int,Int},part::AbstractModelPart,tInt::Int,anyM::anyModel)

	# extract tech info
	carGrp_ntup = part.carrier
	balLvl_ntup = part.balLvl

	tsExp_arr, rExp_arr   = [getfield.(getNodesLvl(anyM.sets[x[2]], balLvl_ntup.exp[x[1]]),:idx) for x in enumerate([:Ts,:R])]
	tsExpSup_arr = map(x -> getDescendants(x,anyM.sets[:Ts],false,anyM.supTs.lvl) |> (y -> typeof(y) == Array{Int,1} ? y : [y] ), tsExp_arr)
	if anyM.options.interCapa != :linear tsExp_arr = map(x -> [minimum(x)],tsExp_arr) end

	expDim_arr = vcat(collect(Iterators.product(Iterators.zip(tsExp_arr,tsExpSup_arr),rExp_arr))...)
	allMap_df =  getindex.(expDim_arr,1) |> (x -> DataFrame(Ts_exp = getindex.(x,1), Ts_expSup = getindex.(x,2), R_exp = getindex.(expDim_arr,2), Te = fill(tInt,length(expDim_arr))))

	stCar_arr::Array{Int,1} = unique(vcat(collect.(map(x -> getproperty(carGrp_ntup,x),intersect(keys(carGrp_ntup),(:stExtIn,:stExtOut,:stIntIn,:stIntOut))))...))
	convCar_arr::Array{Int,1} = unique(vcat(collect.(map(x -> getproperty(carGrp_ntup,x),intersect(keys(carGrp_ntup),(:use,:gen))))...))


	# loops over type of capacities to specify dimensions of capacity variables
	for exp in (:Conv, :StIn, :StOut, :StSize)
		
		# saves required dimensions to dictionary
		if exp == :Conv && !isempty(convCar_arr)
			prepTech_dic[Symbol(:exp,exp)] =  (var = addSupTsToExp(allMap_df,part.par,exp,tsYear_dic,anyM), resi = DataFrame())
		elseif exp != :Conv && !isempty(stCar_arr)
			prepTech_dic[Symbol(:exp,exp)] =  (var = addSupTsToExp(combine(groupby(allMap_df,namesSym(allMap_df)), :Te => (x -> stCar_arr) => :C),part.par,exp,tsYear_dic,anyM), resi = DataFrame())
		else
			continue
		end
		
	end
end

# ! dimensions for capacity variables
function prepareCapacity!(part::AbstractModelPart,prep_dic::Dict{Symbol,NamedTuple},exp_df::DataFrame,capaVar::Symbol,anyM::anyModel; sys::Int = 0)

	sym = capaVar == :capaExc ? :Exc : :Te

	# ! initialize assignments and data
	defPar_tup = tuple(keys(part.par)...)

	capaVar_df = expandExpToCapa(exp_df)

	# groups by expansion time steps in case of mature technologies
	if part.type == :mature
		select!(capaVar_df,Not(:Ts_expSup))
		capaVar_df = unique(capaVar_df)
		capaVar_df[!,:Ts_expSup] .= 0
	end

	# for exchange capacities add column to indicate these values are symmetric
	if sym == :Exc
		capaVar_df[!,:dir] .= part.dir
	end

	# create entry for capacity
	prep_dic[capaVar] =  (var = unique(orderDf(capaVar_df)), resi = DataFrame())
end

# ! add entries for retrofitting variables
function addRetrofitting!(prepSys_dic::Dict{Symbol,Dict{Symbol,Dict{Symbol,NamedTuple}}},anyM::anyModel)

	# ! gather all existing capacity entries that could be relevant for retrofitting
	allCapaDf_dic = Dict{Symbol,DataFrame}()
	retroPotSym_arr = Symbol.(replace.(string.(filter(x -> occursin("costRetro",string(x)), collect(keys(anyM.parts.obj.par)))),"costRetro" => ""))

	for retroSym in intersect(retroPotSym_arr,(:Conv,:StIn,:StOut,:StSize))
		capaSym = Symbol(:capa,retroSym)
		allCapaDf_dic[capaSym] = unique(vcat(filter(w -> !isempty(w), vcat(map(x -> capaSym in keys(x) ? map(y -> getfield(x[capaSym],y) |> (z -> select(z,intCol(z))),[:var,:resi]) : DataFrame[],values(prepSys_dic[:Te]))...))...))
	end
	
	if :Exc in retroPotSym_arr
		capaExc_df = unique(vcat(filter(w -> !isempty(w), vcat(map(x -> :capaExc in keys(x) ? map(y -> getfield(x[:capaExc],y) |> (z -> select(z,intCol(z))),[:var,:resi]) : DataFrame[],values(prepSys_dic[:Exc]))...))...))
		allCapaDf_dic[:capaExc] = filter(x -> anyM.parts.exc[sysSym(x.Exc,anyM.sets[:Exc])].dir || (x.R_from < x.R_to),capaExc_df)
	end

	# ! create actual entries for retrofitting by matching existing capacities with case where costs data was defined
	for sys in (:Te, :Exc)
		sysSym_arr = collect(keys(prepSys_dic[sys]))

		for sSym in sysSym_arr, capaSym in filter(x -> occursin("capa",string(x)), intersect(collect(keys(allCapaDf_dic)),collect(keys(prepSys_dic[sys][sSym]))))
			
			part = sys == :Te ? anyM.parts.tech[sSym] : anyM.parts.exc[sSym]
			retroName_sym = Symbol(replace(string(capaSym),"capa" => "retro"))
			type_sym = Symbol(replace(string(capaSym),"capa" => ""))

			# ! creata dataframe for potential retrofits by filtering for start system
			# filter capacities for relevant system from all system capacities
			relSys_df = filter(x -> x[sys] == sysInt(sSym,anyM.sets[sys]),allCapaDf_dic[capaSym])
			
			# rename columns so they refer to target system, joins with all other capacity entries as starting points and renames them as well
			if capaSym == :capaConv
				relSys_df  = innerjoin(rename(relSys_df, :Ts_expSup => :Ts_expSup_i, sys => Symbol(sys,"_i"), :R_exp => :R_exp_i),allCapaDf_dic[capaSym],on = [:Ts_disSup])
				rename!(relSys_df,:Ts_expSup => :Ts_expSup_j, sys => Symbol(sys,"_j"), :R_exp => :R_exp_j, :Ts_disSup => :Ts_retro)
			elseif capaSym in (:capaStIn, :capaStOut, :capaStSize)
				relSys_df  = innerjoin(rename(relSys_df, :Ts_expSup => :Ts_expSup_i, sys => Symbol(sys,"_i"), :R_exp => :R_exp_i, :C => :C_i),allCapaDf_dic[capaSym],on = [:Ts_disSup])
				rename!(relSys_df,:Ts_expSup => :Ts_expSup_j, sys => Symbol(sys,"_j"), :R_exp => :R_exp_j, :C => :C_j, :Ts_disSup => :Ts_retro)
			else
				relSys_df = innerjoin(rename(relSys_df, :Ts_expSup => :Ts_expSup_i, sys => Symbol(sys,"_i"), :R_from => :R_a_i, :R_to => :R_b_i),allCapaDf_dic[capaSym],on = [:Ts_disSup])
				rename!(relSys_df,:Ts_expSup => :Ts_expSup_j, sys => Symbol(sys,"_j"), :R_from => :R_a_j, :R_to => :R_b_j, :Ts_disSup => :Ts_retro)
			end

			# filter all rows where regions are not related
			relR_dic = Dict(x =>  vcat([x],getAncestors(x,anyM.sets[:R],:int)...,getDescendants(x,anyM.sets[:R])...) for x in (sys != :Exc ? unique(relSys_df[!,:R_exp_i]) : unique(vcat(map(z -> relSys_df[!,z],[:R_a_j,:R_a_i,:R_b_j,:R_b_i])...))))
			filter!(x -> capaSym != :capaExc ? x.R_exp_j in relR_dic[x.R_exp_i] : (x.R_a_j in relR_dic[x.R_a_i] && x.R_b_j in relR_dic[x.R_b_i]),relSys_df)

			# ! match with cost data to see where actual retrofitting is possible
			allRetro_df = select(orderDf(matchSetParameter(relSys_df,anyM.parts.obj.par[Symbol(:costRetro,replace(String(capaSym),"capa" => ""))],anyM.sets)),Not([:val]))
			if isempty(allRetro_df) continue end

			# ! add column for last superordinate timestep of operation
			# add column for last superordinate dispatch timesteps capacity would be operating
			allRetro_df[!,:Ts_disSup_last] = map(x -> filter(y -> y >= x,collect(anyM.supTs.step)),allRetro_df[!,:Ts_retro])
			allRetro_df = flatten(allRetro_df,:Ts_disSup_last)
			
			# join lifetime of starting technology
			if capaSym == :capaConv
				allRetro_df[!,:lifeStart] = matchSetParameter(rename(select(allRetro_df,:Te_i, :Ts_expSup_i, :R_exp_i),:Te_i => :Te, :Ts_expSup_i => :Ts_expSup, :R_exp_i => :R_exp),part.par[Symbol(:life,type_sym)],anyM.sets)[!,:val]
			elseif capaSym in (:capaStIn, :capaStOut, :capaStSize)
				allRetro_df[!,:lifeStart] = matchSetParameter(rename(select(allRetro_df,:Te_i, :Ts_expSup_i, :R_exp_i,:C_i),:Te_i => :Te, :Ts_expSup_i => :Ts_expSup, :R_exp_i => :R_exp,:C_i => :C),part.par[Symbol(:life,type_sym)],anyM.sets)[!,:val]
			else
				allRetro_df[!,:lifeStart] = matchSetParameter(rename(select(allRetro_df,:Exc_i, :Ts_expSup_i, :R_a_i,:R_b_i),:Exc_i => :Exc, :Ts_expSup_i => :Ts_expSup, :R_a_i => :R_a, :R_b_i => :R_b),part.par[Symbol(:life,type_sym)],anyM.sets)[!,:val]
			end

			# filters cases where last superordinate dispatch timesteps of operating would be so far in the future, that combination is impossible due to the lifetime
			filter!(x -> (x.Ts_disSup_last-x.Ts_retro) * anyM.options.shortExp <= x.lifeStart, allRetro_df)
			
			# ! compute all timesteps in lifetime of target capacity
			# get credit factor for lifetime of retrofitted capacity and new lifetime from retrofitting to get the lifetime of new unit
			allRetro_df = matchSetParameter(allRetro_df,part.par[Symbol(:creditRetro,type_sym)],anyM.sets,newCol = :credit)
			allRetro_df = matchSetParameter(allRetro_df,part.par[Symbol(:lifeRetro,type_sym)],anyM.sets,newCol = :lifeRetroSys)
			allRetro_df[!,:lifeRetro] = map(x -> ((x.Ts_disSup_last-x.Ts_retro) * anyM.options.shortExp + x.lifeStart % anyM.options.shortExp) * x.credit + x.lifeRetroSys, eachrow(allRetro_df))

			# compute array of superordinate timesteps in lifetime
			allRetro_df[!,:Ts_disSup] = map(x -> filter(z -> z >= x.Ts_retro && z <= x.lifeRetro,collect(anyM.supTs.step)),eachrow(allRetro_df))
			allRetro_df = orderDf(select!(allRetro_df,Not([:lifeStart,:credit,:lifeRetroSys,:lifeRetro])))

			# add entries for start technology for retrofitting
			prepSys_dic[sys][sSym][retroName_sym] = (var = adjustRetroRegion(sys,allRetro_df), resi = DataFrame()) 

			# ! adjusts capacities for start

			# if the start technology is a stock technology being a start to retrofitting still makes it necessary to create a variable for installed capacity
			if part.type == :stock
				# filter cases where retrofitting necessitates an explict variable for installed capacities 
				select_arr = sys == :Te ? capaSym != :capaConv ? [:Te_j,:Ts_expSup_j,:R_exp_j,:C_j] : [:Te_j,:Ts_expSup_j,:R_exp_j] : [:Ts_expSup_j,:R_a_j,:R_b_j,:Exc_j]
				startCapa_df = unique(select(flatten(allRetro_df,:Ts_disSup),Not(vcat([:Ts_retro,:Ts_disSup_last],select_arr))))
				# find matches with provided resiudal capacities
				join1_arr = vcat([:Ts_disSup,:Ts_expSup], sys == :Te ? (capaSym != :capaConv ? [:R_exp,:Te,:C] : [:R_exp,:Te]) : [:R_from,:R_to,:Exc])
				join2_arr = vcat([:Ts_disSup], sys == :Te ? (capaSym != :capaConv ? [:Ts_expSup_i, :R_exp_i, :Te_i, :C_i] : [:Ts_expSup_i, :R_exp_i, :Te_i]) : [:Ts_expSup_i,:R_a_i,:R_b_i,:Exc_i])
				capa_df = innerjoin(select(prepSys_dic[sys][sSym][capaSym].resi,Not([:var])), startCapa_df, on = join1_arr .=> join2_arr)
				# adds capacity entries to dictionary
				prepSys_dic[sys][sSym][capaSym] = prepSys_dic[sys][sSym][capaSym] |> (z -> (var = orderDf(unique(vcat(z.var,capa_df))), resi = orderDf(z.resi)))
			end
			
			capa_df = prepSys_dic[sys][sSym][capaSym].var

			# ! create new entries for start grouped by operating year
			# add column for last superordinate dispatch timesteps capacity would be operating, analogously to above 	
			capa_df[!,:Ts_disSup_last] = map(x -> filter(y -> y >= x,collect(anyM.supTs.step)),capa_df[!,:Ts_disSup])
			if !isempty(capa_df)
				capa_df = flatten(capa_df,:Ts_disSup_last)
				capa_df[!,:lifeStart] = matchSetParameter(capa_df,part.par[Symbol(:life,type_sym)],anyM.sets)[!,:val]
				filter!(x -> (x.Ts_disSup_last-x.Ts_disSup) * anyM.options.shortExp <= x.lifeStart, capa_df)
				select!(capa_df,Not([:lifeStart]))
			end

			# ! compute new residual capacities for start grouped by laster operating year
			# add column for last superordinate dispatch timesteps capacity would be operating, analogously to above 	
			resi_df = prepSys_dic[sys][sSym][capaSym].resi
			allGrp_arr = DataFrame[]
			if !isempty(resi_df)
				resi_df[!,:Ts_disSup_last] = map(x -> filter(y -> y >= x,collect(anyM.supTs.step)),resi_df[!,:Ts_disSup])
				# groups by region and year of expansion
				resi_df = flatten(resi_df,:Ts_disSup_last)
				resiGrp_df = groupby(resi_df,capaSym == :capaConv ? [:Ts_expSup,:R_exp] : (capaSym == :capaExc ? [:Ts_expSup,:R_from,:R_to] : [:Ts_expSup,:R_exp,:C]))
				# loops over element of group to adjust residual values according to last year of operation
				for x in resiGrp_df
					grp_df = DataFrame(x)
					grp_df[!,:newResi] .= 0.0 # adds columns for new residual capacity based on last year of operation
					sortDisSup_arr = sort(unique(grp_df[!,:Ts_disSup]), rev=true)

					for a in sortDisSup_arr
						# computes value for lattest year of operation in superordinate timestep a
						newResi_fl = filter(x -> x.Ts_disSup == a && x.Ts_disSup_last == a,grp_df)[1,:var].constant - sum(filter(x -> x.Ts_disSup == a,grp_df)[:,:newResi])
						# adds value for same lattest year, but other superordinate timesteps, if possible
						grp_df[!,:newResi] = map(x -> x.Ts_disSup_last == a ?  min(newResi_fl,x.var.constant) : x.newResi,eachrow(grp_df))
					end
					grp_df[!,:var] = map(x -> AffExpr(x),grp_df[!,:newResi])
					push!(allGrp_arr,select(grp_df,Not([:newResi])))
				end
			end
			# write new information on required variables
			resi_df = isempty(allGrp_arr) ? resi_df : orderDf(vcat(allGrp_arr...))
			prepSys_dic[sys][sSym][Symbol(:grp,makeUp(capaSym))] = (var = capa_df, resi = resi_df)
			prepSys_dic[sys][sSym][capaSym] = (var = prepSys_dic[sys][sSym][capaSym].var, resi = filter(x -> false,resi_df)) # remove residual capacities from installed entry now

			# ! add entries for target technology
			st_boo = sys == :Te && capaSym != capaSym
			for s in unique(allRetro_df[!,Symbol(sys,"_j")])
				prepSys_dic[sys][sysSym(s,anyM.sets[sys])][retroName_sym] = (var = orderDf(adjustRetroRegion(sys,filter(x -> x[Symbol(sys,"_j")] == s, allRetro_df),false)), resi = filter(x -> false,resi_df))
			end
		end
	end
	
    return allCapaDf_dic
end

# ! ensures regions are on the level of the start or target system
function adjustRetroRegion(sys::Symbol,retro_df::DataFrame,start::Bool=true)
	
	# check if start or target region should be overwritten
	if start 
		keep_sym = :i; drop_sym = :j
	else
		keep_sym = :j; drop_sym = :i
	end
	# adjusts respective regions
	if sys != :Exc
		retro_df[!,Symbol(:R_exp_,drop_sym)] = retro_df[!,Symbol(:R_exp_,keep_sym)] 
	else
		retro_df[!,Symbol(:R_a_,drop_sym)] = retro_df[!,Symbol(:R_a_,keep_sym)]; 
		retro_df[!,Symbol(:R_b_,drop_sym)] = retro_df[!,Symbol(:R_b_,keep_sym)]
	end
	return unique(retro_df)
end

# ! remove entries where expansion or capacity is fixed zero and no capacity can be created via retrofitting
function removeFixed!(prepSys_dic::Dict{Symbol,Dict{Symbol,Dict{Symbol,NamedTuple}}},allCapaDf_dic::Dict{Symbol,DataFrame},anyM::anyModel)

	for sys in (:Te,:Exc)
		sysSym_arr = filter(x -> getfield(anyM.parts, sys == :Te ? :tech : :exc)[x].type != :stock, collect(keys(prepSys_dic[sys])))

		for sSym in sysSym_arr

			# find entries of existing preparation dictionary where variables are already fixed to zero and remove them
			for prepSym in collect(keys(prepSys_dic[sys][sSym]))
				# get relevant parameter data
				limPar_obj = getLimPar(anyM.parts.lim,Symbol(prepSym,:Fix),anyM.sets[sys], sys = sysInt(sSym,anyM.sets[sys]))
				remainCapa_df = sys == :Te ? filterZero(prepSys_dic[sys][sSym][prepSym].var,limPar_obj,anyM) : convertExcCol(filterZero(convertExcCol(prepSys_dic[sys][sSym][prepSym].var),limPar_obj,anyM))

				prepSys_dic[sys][sSym][prepSym] = prepSys_dic[sys][sSym][prepSym] |> (x -> (var = removeEntries([remainCapa_df],x.var),resi = x.resi))
			end

			# filter enries of preparation dictionary where capacity variable cannot exist, because there is no corresponding expansion or retrofitting variable 
			for capaSym in filter(x -> occursin("capa",string(x)), intersect(collect(keys(allCapaDf_dic)),collect(keys(prepSys_dic[sys][sSym]))))

				# get and expand related entries for expansion
				potCapa_df = expandExpToCapa(prepSys_dic[sys][sSym][Symbol(replace(string(capaSym),"capa" => "exp"))].var)
				
				# get and expand related entries for retrofitting
				retro_sym = Symbol(replace(string(capaSym),"capa" => "retro"))
				if retro_sym in keys(prepSys_dic[sys][sSym])
					if sys == :Te && capaSym == :capaConv
						retro_df = rename(select(prepSys_dic[sys][sSym][retro_sym].var,Not([:Ts_retro,:Ts_disSup_last,:Ts_expSup_i, :R_exp_i, :Te_i])),:Te_j => :Te, :R_exp_j => :R_exp, :Ts_expSup_j => :Ts_expSup)
					elseif sys == :Te
						retro_df = rename(select(prepSys_dic[sys][sSym][retro_sym].var,Not([:Ts_retro,:Ts_disSup_last,:Ts_expSup_i, :R_exp_i, :Te_i, :C_i])),:Te_j => :Te, :R_exp_j => :R_exp, :Ts_expSup_j => :Ts_expSup, :C_j => :C)
					else
						retro_df = rename(select(prepSys_dic[sys][sSym][retro_sym].var,Not([:Ts_retro,:Ts_disSup_last,:Ts_expSup_i, :R_a_i, :R_b_i, :Exc_i])),:Exc_j => :Exc, :R_a_j => :R_from, :R_b_j => :R_to, :Ts_expSup_j => :Ts_expSup)
					end
					potCapa_df = unique(vcat(potCapa_df,flatten(retro_df,:Ts_disSup)))
				end

				# groups by expansion time steps in case of mature technologies
				if getfield(anyM.parts, sys == :Te ? :tech : :exc)[sSym].type == :mature
					potCapa_df[!,:Ts_expSup] .= 0
					potCapa_df = unique(potCapa_df)
				end

				# only preserve capacity entries that could be created based on expansion and retrofitting
				prepSys_dic[sys][sSym][capaSym] = prepSys_dic[sys][sSym][capaSym] |> (x -> (var = innerjoin(x.var, potCapa_df, on = intCol(x.var)), resi = x.resi))
			end
		end
	end
end

# ! add entries for installed capacity
function addInsCapa!(prepSys_dic::Dict{Symbol,Dict{Symbol,Dict{Symbol,NamedTuple}}},anyM::anyModel)

	# add installed capacity for exchange
	for excSym in collect(keys(prepSys_dic[:Exc]))
		prepExc_dic = prepSys_dic[:Exc][excSym]
	
		if anyM.parts.exc[excSym].decomm != :none && :capaExc in keys(prepExc_dic)
			prepExc_dic[:insCapaExc] =  (var = prepExc_dic[:capaExc].var, resi = prepExc_dic[:capaExc].resi)
			excResi_df = select(prepExc_dic[:capaExc].resi,Not([:var]))
			prepExc_dic[:capaExc] =  (var = unique(vcat(prepExc_dic[:capaExc].var, filter(x -> x.R_from < x.R_to, vcat(excResi_df,rename(excResi_df,:R_from => :R_to,:R_to => :R_from))))), resi = DataFrame())
		end
	end

	# add installed capacity for technologies
	for tSym in collect(keys(prepSys_dic[:Te]))
		prepTech_dic = prepSys_dic[:Te][tSym]
		if anyM.parts.tech[tSym].decomm != :none
			for capTy in intersect(keys(prepTech_dic),(:capaConv,:capaStIn,:capaStOut,:capaStSize,:capaExc))
				prepTech_dic[Symbol(:ins,makeUp(capTy))] =  (var = prepTech_dic[capTy].var, resi = prepTech_dic[capTy].resi)
				prepTech_dic[capTy] =  (var = anyM.parts.tech[tSym].type != :stock ? prepTech_dic[capTy].var :  select(prepTech_dic[capTy].resi,Not([:var])), resi = DataFrame())
			end
		end
	end
end

#endregion

#region # * create investment related variables and constraints

# ! create expansion and capacity variables
function createExpCap!(part::AbstractModelPart,prep_dic::Dict{Symbol,NamedTuple},anyM::anyModel,ratioVar_dic::Dict{Symbol,Pair{String,String}} = Dict{Symbol,Pair{String,String}}())
	for expVar in sort(collectKeys(keys(prep_dic)))
		varMap_tup = prep_dic[expVar]
		# determines scaling factor
		if occursin("exp",string(expVar)) || occursin("insCapa",string(expVar))
			scaFac_fl = anyM.options.scaFac.insCapa
		else
			scaFac_fl = anyM.options.scaFac.capa
		end

		# create dataframe of capacity or expansion variables by creating the required capacity variables and join them with pure residual values
		var_df = createVar(varMap_tup.var,string(expVar),anyM.options.bound.capa,anyM.optModel,anyM.lock,anyM.sets, scaFac = scaFac_fl)

		# add negative factor to retrofitting variables where technology is the starting point of retrofitting
		exc_boo = occursin("Exc",string(expVar)) 
		if occursin("retro",string(expVar)) 
			sInt = sysInt(Symbol(part.name[end]),anyM.sets[exc_boo ? :Exc : :Te]) 
			var_df[!,:start] = map(x -> x == sInt, var_df[!,Symbol(exc_boo ? :Exc : :Te,:_i)])
			var_df[!,:var] = map(x -> x.start ? -1.0*x.var : x.var,eachrow(var_df))
		end

		# add residual capacities in case of installed capacities
		if !isempty(varMap_tup.resi)
				
			# flips and repeats entries for directed exchange variabes before moving on
			if exc_boo && !part.dir && ((expVar == :capaExc && part.decomm == :none) || (expVar == :insCapaExc && part.decomm != :none))
				var_df = filter(r -> r.dir,var_df) |> (x -> vcat(filter(r -> !r.dir,var_df),vcat(x,rename(x,replace(namesSym(x),:R_to => :R_from, :R_from => :R_to)))))
			end

			# in case of decommissioning, set lower limit of the installed capacity variable to the negative of the residual capacity, so the lower limit for the whole expression is effectively zero
			if occursin("ins",string(expVar))
				if expVar == :insCapaExc # in case of directed exchange the bigger residual capacities in both directions is used as lower bound => symmetric decommissioning of asymmetric capacities
					resi_df = part.dir ? varMap_tup.resi : flipExc(varMap_tup.resi)
					resi_df = combine(groupby(resi_df,filter(x -> x != :dir,intCol(var_df))),:var => (x -> AffExpr(minimum(getfield.(x,:constant)))) => :val)
				else
					resi_df = rename(varMap_tup.resi,:var => :val)
				end
				setLow_df = joinMissing(var_df,resi_df,intCol(var_df),:left,Dict(:val => AffExpr()))
				foreach(x -> set_lower_bound(collect(keys(x.var.terms))[1], -x.val.constant/collect(values(x.var.terms))[1]) ,eachrow(setLow_df))
			end

			# add residual values to expression with variable
			join_arr = intCol(var_df,:dir)
			var_df = combine(x -> (var = x.var + x.var_1,), groupby(joinMissing(var_df,varMap_tup.resi[!,vcat(:var,join_arr...)], join_arr, :outer, Dict(:var => AffExpr(),:var_1 => AffExpr()),true),intCol(var_df,:dir)))
		end

		# expands table of expansion variables to superordinate timesteps and modifies expansion variable accordingly
		if (occursin("exp",string(expVar)) || occursin("retro",string(expVar))) && !isempty(var_df)
			noExpCol_arr = intCol(var_df,:start)
			allDf_arr = map(eachrow(var_df)) do x
				l_int = length(x.Ts_disSup)
				rem_df = repeat(DataFrame(x[noExpCol_arr]), inner = l_int, outer = 1)
				ext_df = DataFrame(Ts_expSup = x.Ts_expSup, Ts_disSup = x.Ts_disSup, var = x.var ./ fill(l_int,l_int) )
				return hcat(rem_df,ext_df)
			end
			var_df = vcat(allDf_arr...)
		end

		if !isempty(var_df)	part.var[expVar] = var_df end
	end
end

# ! connect capacity and expansion variables
function createCapaCns!(part::AbstractModelPart,prep_dic::Dict{Symbol,NamedTuple},cns_dic::Dict{Symbol,cnsCont},excDir_arr::Array = Int[])
    for capaVar in filter(x -> occursin(part.decomm == :none ? "capa" : "insCapa",string(x)),keys(prep_dic))

        index_arr = intCol(part.var[capaVar])
		join_arr = part.type != :mature ? index_arr : filter(x -> x != :Ts_expSup,collect(index_arr))
		exc_boo = occursin("Exc",string(capaVar)) 
		
        # joins corresponding capacity, retrofitting and expansion variables together
		expVar_sym, retroVar_sym = [Symbol(replace(string(capaVar),(part.decomm == :none ? "capa" : "insCapa") => x)) for x in ["exp","retro"]]
		exp_boo, retro_boo = [expVar_sym in keys(part.var), retroVar_sym in keys(part.var)]
		if !(exp_boo || retro_boo) continue end
		
		# gets capacity variables
		cns_df = rename(part.var[capaVar],:var => :capa)

		# filters double entries for directed exchange
		if exc_boo && !part.dir filter!(x -> x.R_from < x.R_to, cns_df) end

		# adds retrofitting variables
		if retro_boo
			retroVar_df = flatten(part.var[retroVar_sym],:Ts_disSup)
			st_boo = occursin("St",string(capaVar)) 
			for w in (:i,:j)
				retro_arr = vcat([Symbol(:Ts_expSup_,w), :Ts_disSup], exc_boo ? [Symbol(:R_a_,w), Symbol(:R_b_,w), Symbol(:Exc_,w)] : (st_boo ? [Symbol(:R_exp_,w), Symbol(:C_,w), Symbol(:Te_,w)] : [Symbol(:R_exp_,w), Symbol(:Te_,w)]))
				if exc_boo && part.dir # TODO flippe nur die einträge von retroVar_df, wo i /j nicht gerichtet	
					noFlip_df = filter(x -> x[Symbol(:Exc_,w == :j ? :i : :j)] in excDir_arr, retroVar_df)
					flip_df = filter(x -> !(x[Symbol(:Exc_,w == :j ? :i : :j)] in excDir_arr), retroVar_df)  |> (y -> vcat(y,rename(y,Symbol(:R_a_,w) => Symbol(:R_b_,w), Symbol(:R_b_,w) => Symbol(:R_a_,w))))
					retroVar_df = vcat(noFlip_df,flip_df)
				end
				retro_df = rename(combine(groupby(retroVar_df,retro_arr), :var => (x -> sum(x)) => :var), retro_arr .=> intCol(cns_df))
				cns_df[!,Symbol(:retro_,w)] = aggDivVar(retro_df,cns_df,tuple(intCol(cns_df)...),anyM.sets)
			end			
		end
		
		# adds expansion variables
		if exp_boo
			expVar_df = flatten(part.var[expVar_sym],:Ts_disSup)
			cns_df = joinMissing(cns_df, combine(groupby(expVar_df,join_arr), :var => (x -> sum(x)) => :exp), join_arr,:left,Dict(:exp => AffExpr()))
		end 

        # creates final constraint object
		cns_df[!,:cnsExpr] = map(x -> x.capa - x.capa.constant + (exp_boo ? - x.exp : 0.0) + (retro_boo ? - x.retro_i - x.retro_j : 0.0),eachrow(cns_df))
		cns_dic[Symbol(capaVar)] = cnsCont(select(cns_df,intCol(cns_df,:cnsExpr)),:equal)
    end
end

# ! create constraints regarding operated variables
function createOprVarCns!(part::AbstractModelPart,cns_dic::Dict{Symbol,cnsCont},anyM::anyModel)

	for capaVar in filter(x -> occursin("capa",string(x)),keys(part.var))
		insVar_sym = string(capaVar) |> (x -> Symbol(:ins,uppercase(x[1]),x[2:end]))
		var_df = part.var[insVar_sym]
		exc_boo = :R_from in intCol(var_df)

		# ! create constraint to connect operated and installed capacity
		if exc_boo
			oprVar_df = part.dir ? part.var[capaVar] : flipExc(part.var[capaVar])
			var_df = leftjoin(var_df,rename(select(oprVar_df,Not([:dir])),:var => :var_2),on = intCol(var_df))
			var_df[!,:cnsExpr] = map(x -> x.var_2 - x.var ,eachrow(var_df))
			select!(var_df,Not([:var_2]))
		else
			var_df[!,:cnsExpr] = map(x -> x[2] - x[1],zip(var_df[!,:var],part.var[capaVar][!,:var]))
		end
		
		cns_dic[string(insVar_sym) |> (x -> Symbol(:de,uppercase(x[1]),x[2:end]))] = cnsCont(select(var_df,Not(:var)),:smaller)

		# ! create constraint to prevent re-commissioning of capacity once decommissioned
		if part.decomm == :decomm
			# add previous period and its capacity variable to table
			prevTs_dic = Dict(x => anyM.supTs.step[findall(x .== anyM.supTs.step)[1]]-1 for x in anyM.supTs.step[2:end])
			select!(var_df, Not(:cnsExpr))
			cns_df = rename(filter(r -> r.Ts_disSup != anyM.supTs.step[1],var_df),:var => :oprNow)
			cns_df[!,:Ts_disSupPrev] = map(x -> prevTs_dic[x] ,cns_df[!,:Ts_disSup])
			cns_df = rename(innerjoin(cns_df,var_df; on = intCol(var_df,:dir) |> (x -> Pair.(replace(x,:Ts_disSup => :Ts_disSupPrev),x))),:var => :oprPrev)

			# add expansion variable to dataframe
			if Symbol(replace(string(capaVar),"capa" => "exp")) in collect(keys(part.var))
				exp_df = part.var[Symbol(replace(string(capaVar),"capa" => "exp"))][!,Not(:Ts_disSup)]
				join_arr = filter(x -> x != :Ts_expSup,intCol(var_df))

				cns_df = joinMissing(cns_df,exp_df, Pair.(join_arr,replace(join_arr,:Ts_disSup => :Ts_expSup)),:left,Dict(:var => AffExpr(),:Ts_exp => 0))
				cns_df = rename(cns_df[!,Not(:Ts_exp)],:var => :expNow)
			else
				cns_df[!,:expNow] .= AffExpr()
			end

			# add retrofitting variable to dataframe
			if Symbol(replace(string(capaVar),"capa" => "retro")) in collect(keys(part.var))
				sInt = unique(cns_df[!,exc_boo ? :Exc : :Te])[1]
				retro_df = filter(x -> x[exc_boo ? :Exc_j : :Te_j] == sInt, part.var[Symbol(replace(string(capaVar),"capa" => "retro"))][!,Not(:Ts_disSup)])
		
				rename_arr = vcat([:Ts_expSup => :Ts_disSup, :Ts_expSup_j => :Ts_expSup],exc_boo ? [:R_a_j => :R_from, :R_b_j => :R_to,:Exc_j => :Exc] : [:R_exp_j => :R_exp,:Te_j => :Te])
				cns_df[!,:retroNow] = aggDivVar(rename(retro_df,rename_arr),cns_df,tuple(filter(x -> x != :Ts_disSupPrev,intCol(cns_df))...),anyM.sets)
		
			else
				cns_df[!,:retroNow] .= AffExpr()
			end

			# add residual capacities of current and previous period
			joinResi_arr = filter(x -> x != :Ts_disSupPrev, intCol(cns_df,:dir))
			cns_df = rename(innerjoin(cns_df,part.var[capaVar],on = joinResi_arr),:var => :resiNow)
			cns_df[!,:resiNow] = getfield.(cns_df[!,:resiNow],:constant)
			cns_df = rename(joinMissing(cns_df, part.var[capaVar], Pair.(replace(joinResi_arr,:Ts_disSup => :Ts_disSupPrev),joinResi_arr),:left, Dict(:resiNow => AffExpr(),:var => AffExpr())),:var => :resiPrev)
			cns_df[!,:resiPrev] = getfield.(cns_df[!,:resiPrev],:constant)

			# create actual constraint information
			cns_df[!,:cnsExpr]  = map(x -> - x.oprNow + x.oprPrev + x.expNow + x.retroNow + (x.resiNow - x.resiPrev |> (l -> l > 0.0 ? l : 0.0)),eachrow(cns_df))
			select!(cns_df,Not([:Ts_disSupPrev,:oprNow,:oprPrev,:expNow,:retroNow,:resiNow,:resiPrev]))
			cns_dic[string(insVar_sym) |> (x -> Symbol(:re,uppercase(x[1]),x[2:end]))] = cnsCont(orderDf(cns_df),:greater)
		end
	end
end

#endregion