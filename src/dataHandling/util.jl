
#region # * reporting of calculation progress and error handling

# ! return elapsed time since Start_date
function getElapsed(start::DateTime)
    elapSec_per = Dates.value(floor(now() - start,Dates.Second(1)))
    if elapSec_per < 3600*24
        elap_str = Dates.format(DateTime(2015,01,01,Int(floor(elapSec_per / 3600)),Int(floor(elapSec_per % 3600/ 60)),elapSec_per % 60), "HH:MM:SS")
    else
        elap_str = Dates.format(DateTime(2015,01,Int(floor(elapSec_per / (3600*24))),Int(floor(elapSec_per % (3600*24) / 3600)),Int(floor(elapSec_per % 3600/ 60)),elapSec_per % 60), "dd:HH:MM:SS")
    end
    return elap_str
end

# ! teste for errors so far and optional writes report file, even if no serious errrors occured yet
function errorTest(report::Array{Tuple,1},options::modOptions;write::Bool = false, inCode::Bool = false)
    errStatus_dic = Dict(1 => :green, 2 => :yellow,3 => :red)
    if any(getindex.(report,1) .== 3)
		output_df = DataFrame(map(idx -> getindex.(report, idx), eachindex(first(report))), [:type, :section, :location, :message])
        CSV.write("$(options.outDir)/reporting_$(options.outStamp).csv",  insertcols!(output_df[!,2:end], 1, :errStatus => map(x -> errStatus_dic[x],output_df[!,:type])))
		printstyled("$(inCode ? "" : " - " )Errors encountered! Wrote reporting_$(options.outStamp).csv for details!"; color = :light_red)
        error()
    else
		numWarn = length(findall(getindex.(report,1) .== 2))
        if write && length(report) > 0
			output_df = DataFrame(map(idx -> getindex.(report, idx), eachindex(first(report))), [:type, :section, :location, :message])
            CSV.write("$(options.outDir)/reporting_$(options.outStamp).csv",  insertcols!(output_df[!,2:end], 1, :errStatus => map(x -> errStatus_dic[x],output_df[!,:type])))
			printstyled("$(inCode ? "" : " - " )No errors and $numWarn warning(s) encountered. Wrote reporting_$(options.outStamp).csv for details! \n"; color = numWarn > 0 ? :light_yellow : :light_green)
        else
			printstyled("$(inCode ? "" : " - " )No errors and $numWarn warning(s) encountered. \n"; color = numWarn > 0 ? :light_yellow : :light_green)
        end
    end
end

# ! produces a output message and tests for errors accordingly to globally set reporting values
function produceMessage(options::modOptions,report::Array{Tuple,1},currentLvl::Int64,fixedString::String,dynamicString::Any="";testErr::Bool = false)
	sty_dic = Dict(1 => :bold, 2 => :normal, 3 => :light_black)

	sty_dic[currentLvl]
    if options.reportLvl >= currentLvl
		if options.errCheckLvl >= currentLvl || testErr
			printstyled(options.objName; color = :underline); printstyled(" ", getElapsed(options.startTime), fixedString, dynamicString; color = sty_dic[currentLvl])
		else
			printstyled(options.objName; color = :underline); printstyled(" ",getElapsed(options.startTime), fixedString, dynamicString, "\n"; color = sty_dic[currentLvl])
		end
	end
    if options.errCheckLvl >= currentLvl || testErr errorTest(report,options,write = options.errWrtLvl >= currentLvl) end
end

#endregion

#region # * miscellaneous data processing

# ! new plus function to avoid error when one element being added up is nothing
plus(a::Int,b::Int) = a + b
plus(a::Int,b::Nothing) = a
plus(a::Nothing,b::Int) = b

# ! creates array of string from typical input of array
makeC(in::String) = split(replace(in," " => ""),";")

# ! provides names of columns as array of symbols ('names' function itself was changed from strings to symbols)
namesSym(df::DataFrame) = map(x -> Symbol(x),names(df))
namesSym(df::DataFrameRow) = map(x -> Symbol(x),names(df))

# ! to add an "and $nameOfScenario" or nothing to a reporting line
getScrName(id::Int,scr_tree::Tree) = id != 0 ? " and scenario '$(createFullString(id,scr_tree))'" : ""

# ! returns dataframe columns without value column
removeVal(input_df::DataFrame) = filter(x -> !(x in (:val,:ratio)),namesSym(input_df))
removeVal(col_arr::Array{Symbol,1}) = filter(x -> !(x in (:val,:ratio)),col_arr)

# ! return an empty integer array instead of an error, if a key is not in a dictionary
getDicEmpty(dic::Dict,key::Any) = key in keys(dic) ? dic[key] : Int[]

# ! get names of column of type integer
intCol(in_df::DataFrame) = getindex.(filter(x -> eltype(x[2]) <: Int, collect(pairs(eachcol(in_df)))),1)
intCol(in_df::DataFrame,add_sym::Symbol) = union(intCol(in_df),intersect(namesSym(in_df),[add_sym]))
intCol(in_df::DataFrame,add_sym::Array) = union(intCol(in_df),intersect(namesSym(in_df),add_sym))

# ! returns the number of different capacity groups of storage from named tuple of carriers
countStGrp(carGrp_ntup::NamedTuple) = intersect((:stExtIn,:stsExtOut,:stIntIn,:stsIntOut),collect(keys(carGrp_ntup))) |> (z ->  isempty(z) ? 0 : maximum(map(x -> length(getfield(carGrp_ntup,x)),z)))

# ! puts relevant dimensions in consistent order and adds remaining entries at the end
orderDim(inDim_arr::Array{Symbol,1},intCol_arr::Array{Symbol,1}) = intersect([:Ts_exp, :Ts_retro, :Ts_expSup, :Ts_disSup_last, :Ts_expSup_i, :Ts_expSup_j, :Ts_expSup_a, :Ts_expSup_b, :Ts_disSup, :Ts_dis, :R_exp, :R_exp_i, :R_exp_j, :R_exp_from, :R_exp_to, :R_dis, :R_from, :R_to, :R_from_i, :R_to_i, :R_from_j, :R_to_j, :C, :Te, :Te_i, :Te_j, :Exc_i, :Exc_j, :M, :scr,:variable,:value], intersect(inDim_arr,intCol_arr)) |> (x -> [x...,setdiff(inDim_arr,x)...])
orderDim(inDim_arr::Array{Symbol,1}) = intersect([:Ts_exp, :Ts_retro, :Ts_expSup, :Ts_disSup_last, :Ts_expSup_i, :Ts_expSup_j, :Ts_expSup_a, :Ts_expSup_b, :Ts_disSup, :Ts_dis, :R_exp, :R_exp_i, :R_exp_j, :R_exp_from, :R_exp_to, :R_dis, :R_from, :R_to, :R_from_i, :R_to_i, :R_from_j, :R_to_j, :C, :Te, :Te_i, :Te_j, :Exc_i, :Exc_j, :M, :scr,:variable,:value], inDim_arr) |> (x -> [x...,setdiff(inDim_arr,x)...])

# ! puts dataframes columns in consistent order
orderDf(in_df::DataFrame) = select(in_df,orderDim(namesSym(in_df),intCol(in_df) |> (z -> isempty(z) ? Symbol[] : z)))

# ! writes all tuples occuring in a tuple of pairs and tuples
mixedTupToTup(x) = typeof(x) <: Pair ? map(y -> mixedTupToTup(y),collect(x)) :  x

# ! check if dataframe should be considered, if energy balance is created for carriers in array
filterCarrier(var_df::DataFrame,c_arr::Array{Int,1}) = :C in namesSym(var_df) ? filter(r -> r.C in c_arr,var_df) : var_df

# ! makes first letter of string or symbol capital or non-capital
makeUp(in::String) = isempty(in) ? "" : string(uppercase(in[1]),in[2:end])
makeUp(in::Symbol) = Symbol(uppercase(string(in)[1]),string(in)[2:end])

# ! create dataframe with all potential dimensions for carrier provided
function createPotDisp(c_arr::Array{Int,1},ts_dic::Dict{Tuple{Int64,Int64},Array{Int64,1}},anyM::anyModel)

	lvl_arr = map(x -> anyM.cInfo[x], c_arr) |> (y -> map(z -> getfield.(y,z),[:tsDis, :rDis]))
	allLvl_df = DataFrame(C = c_arr, lvlTs = lvl_arr[1], lvlR = lvl_arr[2])
	rDis_dic = Dict(x => getfield.(getNodesLvl(anyM.sets[:R],x),:idx) for x in unique(lvl_arr[2]))

	allLvl_df[!,:Ts_disSup] .= fill(collect(anyM.supTs.step),size(allLvl_df,1))
	allLvl_df = flatten(allLvl_df,:Ts_disSup)

	allLvl_df[!,:scr]  = map(x -> anyM.supTs.scr[x],allLvl_df[!,:Ts_disSup])
	allLvl_df = flatten(allLvl_df,:scr)

	allLvl_df[!,:Ts_dis] = map(x -> ts_dic[x.Ts_disSup,x.lvlTs],eachrow(allLvl_df))
	allLvl_df[!,:R_dis] = map(x -> rDis_dic[x],allLvl_df[!,:lvlR])

	var_df = flatten(flatten(select(allLvl_df,Not([:lvlTs,:lvlR])),:Ts_dis),:R_dis)

	# add column for superordinate dispatch timestep
	supTs_dic =  Dict(x => getAncestors(x,anyM.sets[:Ts],:int,anyM.supTs.lvl)[end] for x in unique(var_df[!,:Ts_dis]))
	var_df[!,:Ts_disSup] = map(x -> supTs_dic[x], var_df[!,:Ts_dis])

	return var_df
end

# ! gets system (technology or exchange) name as symbol from id and the other way around
sysSym(sInt::Int,sym_tree::Tree) = Symbol(getUniName(sInt,sym_tree)[end])
sysInt(sSym::Symbol,sym_tree::Tree) = filter(x -> x.val == string(sSym),collect(values(sym_tree.nodes)))[1].idx

# ! specifc utilities for exchange 
# converts dataframe where exchange regions are given as "a -> b" or "from -> to" to other way round
switchExcCol(in_df::DataFrame) = rename(in_df, replace(namesSym(in_df),:R_from => :R_to, :R_to => :R_from))
#  appends input dataframe to switches version of itself
flipExc(in_df) = vcat(in_df,switchExcCol(in_df))

#endregion

#region # * data frame based manipulations

# ! finds entries where expansion or capacity would be fixed to zero
function filterZero(src_df::DataFrame,par_obj::ParElement,anyM::anyModel)
	if isdefined(par_obj,:name)
	# copies parameter obj and adds ":up" to inheritance for any dimensions, otherwise variables would be created, but fixed to zero due to a zero limit on a higher level in the tree
		modPar_obj = par_obj
		modPar_obj.herit = modPar_obj.herit |> (y -> tuple(vcat(y..., map(x -> x => :up,getindex.(y,1))...)...))
		# filter zero cases
		zero_df = select!(filter(r -> r.val == 0, matchSetParameter(src_df, modPar_obj, anyM.sets)),Not(:val))
	else
		zero_df = src_df[[],:]
	end
	return zero_df
end

# ! removes all entries occuring in remove array from input table
function removeEntries(remove_arr::Array{DataFrame,1},input_df::DataFrame)
    if !isempty(remove_arr)
        remove_df = length(remove_arr) == 1 ? remove_arr[1] : vcat(remove_arr...)
        colRemove_arr = namesSym(remove_df)
		out_df = antijoin(input_df,remove_df; on = colRemove_arr)
		return out_df
    else
        return input_df
    end
end

# ! merge provided dataframe into prep_dic
function mergePrepDic!(key_sym::Symbol,prep_dic::Dict{Symbol,NamedTuple},capaResi_df::DataFrame)
	if key_sym in keys(prep_dic)
		prep_dic[key_sym]= (var = prep_dic[key_sym].var, resi = capaResi_df)
	else
		prep_dic[key_sym] = (var = intCol(capaResi_df) |> (x -> DataFrame(Pair.(x,fill(Int[],length(x))))),resi = capaResi_df)
	end
end

# ! performs a left or outer join operation and replaces any missing values
function joinMissing(leftData_df::DataFrame, rightData_df::DataFrame, key_arr::Union{Array{Symbol,1},Array{Pair{Symbol,Symbol},1}}, how_sym::Symbol, missVal_dic::Dict, uni_boo::Bool = false)

	# perform join operation
	if how_sym == :left
		joinData_df = leftjoin(leftData_df,rightData_df; on = key_arr, makeunique = uni_boo)
	elseif how_sym == :outer
		joinData_df = outerjoin(leftData_df,rightData_df; on = key_arr, makeunique = uni_boo)
	end

	miss_col = filter(x -> any(ismissing.(x[2])), collect(pairs(eachcol(joinData_df))))
    # check, if any column contains missing values
    if isempty(miss_col) return dropmissing(joinData_df) end

    # replace missing value, cases differ depending if data type needs to be adjusted
    for col in miss_col
        joinData_df[!,col[1]] = map(x -> coalesce(x,missVal_dic[col[1]]),col[2])
    end

    return dropmissing(joinData_df)
end

# ! get array of scaling factors for add_df
function getResize(add_df::DataFrame,time_obj::Tree,supDis::NamedTuple)
    tsDisLvl_dic = Dict(x => x == 0 ? 1 : getfield(time_obj.nodes[x],:lvl) for x in unique(add_df[!,:Ts_dis]))
	lvl_arr = map(x -> tsDisLvl_dic[x],add_df[!,:Ts_dis])
	aboveSupResize_fl = maximum(values(supDis.sca)) * length(supDis.step) # scaling value used for variables above the superordinate dispatch level
	sca_arr = map(x -> supDis.lvl > x[1] ? aboveSupResize_fl : supDis.sca[(x[2],x[1])] ,zip(lvl_arr,add_df[!,:Ts_disSup]))
    return sca_arr
end

# ! gets the upper bound used for dispatch variables
function getUpBound(in_df::DataFrame,dispBound_fl::Float64,supTs::NamedTuple,treeTs::Tree)
	if !isnan(dispBound_fl)
		upBound_arr = dispBound_fl * getResize(in_df,treeTs,supTs)
	else
		upBound_arr = fill(NaN,size(in_df,1))
	end
	return upBound_arr
end

#endregion

#region # * functions and sub-functions to aggregate variables

# ! aggregates variables in aggEtr_df to rows in srcEtr_df, function used, if all entries of search have the same resolution (all entries in a relevant column are on the same level)
function aggUniVar(aggEtr_df::DataFrame, srcEtr_df::DataFrame, agg_arr::Array{Symbol,1},srcRes_tup::NamedTuple,sets_dic::Dict{Symbol,Tree})
	if isempty(aggEtr_df) return fill(AffExpr(),size(srcEtr_df,1)) end

	# only selects relevant columns
    aggEtr_df = select(aggEtr_df,vcat(:var,agg_arr...))
	srcEtr_df = select(srcEtr_df,agg_arr)

	# adjusts entries in aggregation dataframe to comply with resolution of search dataframe
	for dim in intersect(keys(srcRes_tup),agg_arr)
		set_sym = Symbol(split(string(dim),"_")[1])
		dim_dic = Dict(x => getAncestors(x,sets_dic[set_sym],:int,getfield(srcRes_tup,dim))[end] for x in unique(aggEtr_df[!,dim]))
		aggEtr_df[!,dim] .= map(x -> dim_dic[x],aggEtr_df[!,dim])
	end

	aggEtrGrp_df = combine(groupby(aggEtr_df,agg_arr), :var => (x -> sum(x)) => :var)
	var_arr = joinMissing(srcEtr_df,aggEtrGrp_df,agg_arr,:left,Dict(:var => AffExpr()))[!,:var]
	return var_arr
end

# ! aggregates variables in aggEtr_df to rows in srcEtr_df, function used, if entries of search can have different resolutions (not all entries in a relevant column are on the same level)
function aggDivVar(aggEtr_df::DataFrame, srcEtr_df::DataFrame, agg_tup::Tuple, sets_dic::Dict{Symbol,Tree}; aggFilt::Tuple = ())

	aff_boo = :var in namesSym(aggEtr_df) # detects if values (meaning Float types) or variables (meaning AffExpr types are aggregated)
	agg_sym = aff_boo ? :var : :val

	# ! sanity checks regarding columns
	if all(namesSym(aggEtr_df) |> (y -> map(x -> !(x in y),agg_tup))) error("tried to perform aggregation on column not existing in dataframe to be aggregated") end
	if all(namesSym(srcEtr_df) |> (y -> map(x -> !(x in y),agg_tup))) error("tried to perform aggregation on column not existing in dataframe to aggregate") end

	select!(aggEtr_df,intCol(aggEtr_df,agg_sym))
	# ! filter entries from aggEtr_df, that based on isolated analysis of columns will not be aggregated
	for dim in intersect(aggFilt,agg_tup)
		set_sym = Symbol(split(string(dim),"_")[1])
		allSrc_set = unique(srcEtr_df[!,dim]) |> (z -> union(BitSet(z),map(x -> BitSet(getDescendants(x,sets_dic[set_sym],true)),z)...))
		aggEtr_df = aggEtr_df[findall(map(x -> (x in allSrc_set),aggEtr_df[!,dim])),:]
	end

	if isempty(aggEtr_df) return fill(aff_boo ? AffExpr() : 0.0,size(srcEtr_df,1)) end

	# ! filter entries from srcEtr_df, that based on isolated anlysis of columns will not have any values aggregated to
	idxRel_set = BitSet(1:size(srcEtr_df,1))
	for dim in filter(x -> !(x in (:id,:id_i,:id_j)), collect(agg_tup))
		set_sym = Symbol(split(string(dim),"_")[1])
		allAgg_set = unique(aggEtr_df[!,dim]) |> (z -> union(BitSet(z),map(y -> BitSet(getAncestors(y,sets_dic[set_sym],:int,0)), z)...))
		idxRel_set = intersect(idxRel_set,BitSet(findall(map(x -> x in allAgg_set, srcEtr_df[!,dim]))))
	end
	srcEtrAct_df = srcEtr_df[collect(idxRel_set),:]
	# group aggregation dataframe to relevant columns and removes unrequired columns
	aggEtrGrp_df = combine(groupby(aggEtr_df,collect(agg_tup)), agg_sym => (x -> sum(x)) => agg_sym)

	# ! create dictionaries in each dimension that assign rows suited for aggregation for each value
	chldRows = Dict{Symbol,Dict{Int,BitSet}}()
	for col in agg_tup
		# row that are potentially aggregated
		findCol_arr = aggEtrGrp_df[!,col]
		findCol_set = BitSet(findCol_arr)

		# entries that other entries can be aggregated to
		searchVal_set = BitSet(unique(srcEtrAct_df[!,col]))

		# to every unique value in column the value itself and its children are assigned
		set_sym = Symbol(split(string(col),"_")[1])
		idxChild_dic = !(col in (:id,:id_i,:id_j)) ? Dict(x => intersect(findCol_set,[x,getDescendants(x,sets_dic[set_sym],true)...]) for x in searchVal_set) : Dict(x => x for x in searchVal_set)

		# for each unique value in column the rows with children are assigned
		grp_df = groupby(DataFrame(val = findCol_arr, id = 1:length(findCol_arr)),:val)
		dicVal_dic = Dict(x.val[1] => BitSet(sort(x[!,:id])) for x in grp_df) |> (dic -> Dict(x => union(map(y -> dic[y],collect(idxChild_dic[x]))...) for x in keys(idxChild_dic)))
		# excludes column from search, if based on it, every entry in find could be aggregated to every row in search
		# (if this holds true for all columns, make an exception for the last one and dont remove it to, because otherwise correct aggregation cannot happen )
		if all(length.(values(dicVal_dic)) .== length(findCol_arr)) && !(col == agg_tup[end] && length(chldRows) < 1)
			select!(srcEtrAct_df,Not(col)); continue
		else
			chldRows[col] = dicVal_dic
		end
	end

	# ! finds aggregation by intersecting suited rows in each dimension
	if isempty(chldRows)
		aggRow_arr = fill(BitSet(),size(srcEtrAct_df,1))
	else
		aggRow_arr = collectKeys(keys(chldRows)) |> (y -> map(x -> intersect(map(y -> chldRows[y][x[y]],y)...) ,eachrow(srcEtrAct_df)))
	end

	# ! aggregates values according to lookup
	out_arr = aff_boo ? Array{AffExpr}(undef,size(srcEtr_df,1)) : Array{Float64}(undef,size(srcEtr_df,1))
	out_arr[collect(idxRel_set)] =  map(x -> sum(aggEtrGrp_df[x,agg_sym]), collect.(aggRow_arr))
	out_arr[setdiff(1:size(srcEtr_df,1),idxRel_set)] .= aff_boo ? AffExpr() : 0.0

	return out_arr
end

#endregion

#region # * manipulate model related data frames

# ! add superordinate dispatch timestep to expansion dataframe
function addSupTsToExp(expMap_df::DataFrame,para_obj::Dict{Symbol,ParElement},type_sym::Symbol,tsYear_dic::Dict{Int,Int},anyM::anyModel)
	if !isempty(expMap_df)
		lftm_df = matchSetParameter(flatten(expMap_df,:Ts_expSup),para_obj[Symbol(:life,type_sym)],anyM.sets,newCol = :life)
		if Symbol(:del,type_sym) in keys(para_obj) # only add an acutal delay for normal expansion, but not in case of retrofitting
			lftmDel_df = matchSetParameter(lftm_df,para_obj[Symbol(:del,type_sym)],anyM.sets,newCol = :del)
		else
			lftmDel_df = lftm_df; lftmDel_df[!,:del] .= 0.0
		end
		lftmDel_df[!,:Ts_disSup] = map(x -> filter(y -> (tsYear_dic[y] >= tsYear_dic[x.Ts_expSup] + x.del) && (tsYear_dic[y] <= tsYear_dic[x.Ts_expSup] + x.life + x.del),collect(anyM.supTs.step)), eachrow(lftmDel_df))
		select!(lftmDel_df,Not([:life,:del]))
		grpCol_arr = intCol(expMap_df) |> (x -> :ratio in namesSym(expMap_df) ? vcat(:ratio,x...) : x)
		expMap_df = combine(groupby(lftmDel_df,grpCol_arr), [:Ts_expSup,:Ts_disSup] .=> (x -> [x]) .=> [:Ts_expSup,:Ts_disSup])
	else
		expMap_df[!,:Ts_disSup] = Array{Array{Int,1},1}()
	end
	return expMap_df
end

# ! expand expansion dataframe to capacity dataframe
function expandExpToCapa(in_df::DataFrame)

	noExpCol_arr = intCol(in_df)

	allDf_arr = map(eachrow(in_df)) do x
		l_arr = length.(x.Ts_disSup)
		rem_df = repeat(DataFrame(x[noExpCol_arr]), inner = sum(l_arr), outer = 1)
		ext_df = DataFrame(Ts_expSup = vcat(map(y -> fill(x.Ts_expSup[y],l_arr[y]),1:length(l_arr))...), Ts_disSup = vcat(x.Ts_disSup...))
		return hcat(rem_df,ext_df)
	end

	if !isempty(allDf_arr)
		capa_df = select(vcat(allDf_arr...),orderDim(namesSym(allDf_arr[1])))[!,Not(:Ts_exp)]
	else
		 capa_df = select(in_df,Not(:Ts_exp)); capa_df[!,:Ts_disSup] = Int[];
	end

	return orderDf(capa_df)
end

# ! expands any table including columns with temporal and spatial dispatch levels and the corresponding expansion regions and superordinate dispatch steps to full dispatch table
function expandExpToDisp(inData_df::DataFrame,ts_dic::Dict{Tuple{Int,Int},Array{Int,1}},r_dic::Dict{Tuple{Int64,Int64},Array{Int64,1}},scr_dic::Dict{Int64,Array{Int64,1}},preserveTsSupTs::Bool = false)

	inData_df[!,:scr] = map(x -> scr_dic[x], inData_df[!,:Ts_disSup])
	inData_df = flatten(inData_df,:scr)

	# adds regional timesteps and check if this causes non-unique values (because spatial expansion level can be below dispatch level)
	expR_df = unique(combine(x -> (R_dis = r_dic[(x.R_exp[1],x.lvlR[1])],), groupby(inData_df,namesSym(inData_df)))[!,Not([:R_exp,:lvlR])])
	expTs_df = combine(x -> (Ts_dis = ts_dic[(x.Ts_disSup[1],x.lvlTs[1])],), groupby(expR_df,namesSym(expR_df)))[!,Not(:lvlTs)]

    # adds dispatch timesteps to table and returns
	if !preserveTsSupTs select!(expTs_df,Not(:Ts_disSup)) end
	return expTs_df
end

# ! obtains residual capacities for technologies
function checkResiCapa(var_sym::Symbol, stockCapa_df::DataFrame, part::AbstractModelPart, anyM::anyModel, addSym::Symbol = Symbol())
	resiPar_sym = Symbol(var_sym,:Resi,addSym)
	if resiPar_sym in tuple(keys(part.par)...)
		# search for defined residual values
		stock_df = matchSetParameter(stockCapa_df, part.par[resiPar_sym], anyM.sets)
	else
		stock_df = filter(x -> false,stockCapa_df); stock_df[!,:val] = Float64[]
	end

	# convers returned value to affine expression
	stock_df[!,:var] =  AffExpr.(stock_df[!,:val])
	select!(stock_df,Not(:val))

   return stock_df
end

# ! get a dataframe with all variable of the specified type
function getAllVariables(va::Symbol,anyM::anyModel; reflectRed::Bool = true, filterFunc::Function = x -> true)

	varToPart_dic = Dict(:exc => :exc, :capaExc => :exc, :insCapaExc => :exc, :expExc => :exc, :crt => :bal, :lss => :bal, :trdSell => :trd, :trdBuy => :trd, :emission => Symbol())
	techSym_arr = collect(keys(anyM.parts.tech))

	if !(va in keys(varToPart_dic)) # get all variables for technologies
		va_dic = Dict(:stIn => (:stExtIn, :stIntIn), :stOut => (:stExtOut, :stIntOut), :in => (:use,:stIntOut), :out => (:gen,:stIntIn))
		techType_arr = filter(x -> !isempty(x[2]),[(vaSpec,filter(y -> vaSpec in keys(anyM.parts.tech[y].var), techSym_arr)) for vaSpec in (va in keys(va_dic) ? va_dic[va] : (va,))])

		if !isempty(techType_arr)
			allVar_df = vcat(map(x -> anyM.parts.tech[x[2]].var[x[1]], vcat(map(x -> collect(zip(fill(x[1],length(x[2])),x[2])),techType_arr)...))...)
		else
			allVar_df = DataFrame()
		end

		# aggregate variables if different types where obtained
		if va in keys(va_dic) && !isempty(allVar_df)
			allVar_df = combine(groupby(allVar_df, intCol(allVar_df)), :var => (x -> sum(x)) => :var)
		end
	elseif va != :emission # get variables from other parts
		if va in keys(getfield(anyM.parts,varToPart_dic[va]).var)
			allVar_df = getfield(anyM.parts,varToPart_dic[va]).var[va]
		else
			allVar_df = DataFrame()
		end
	else va == :emission # for emission all use variables are obtained and then already matched with emission factors

		if !(:emissionFac in keys(anyM.parts.lim.par))
			lock(anyM.lock)
			push!(anyM.report,(2,"limits","emissionUp","upper emission limits but no emission factors provided"))
			unlock(anyM.lock)
			allVar_df = DataFrame()
		else
			# get all carriers and technologies that might be relevant to compute emissions
			if :Te in namesSym(anyM.parts.lim.par[:emissionFac].data)
				emC_arr = unique(vcat(map(x -> [x,getDescendants(x,anyM.sets[:C],true)...],unique(filter(x -> x.Te == 0, anyM.parts.lim.par[:emissionFac].data)[!,:C]))...))
				emTe_arr = unique(vcat(map(x -> [x,getDescendants(x,anyM.sets[:Te],true)...],unique(filter(x -> x.Te != 0, anyM.parts.lim.par[:emissionFac].data)[!,:Te]))...))
			else
				emC_arr = unique(vcat(map(x -> [x,getDescendants(x,anyM.sets[:C],true)...],unique(anyM.parts.lim.par[:emissionFac].data[!,:C]))...))
				emTe_arr = Array{Int64,1}()
			end

			# get use variables
			allVar_df = getAllVariables(:use,anyM, filterFunc = x -> x.C in emC_arr || x.Te in emTe_arr)

			# get expressions for storage and exchange losses, if this is enabled
			if anyM.options.emissionLoss

				# get all carriers being stored
				allSt_arr = unique(vcat(vcat(map(x -> map(y -> collect(x.carrier[y]),intersect(keys(x.carrier),(:stExtIn,:stExtOut,:stIntIn,:stIntOut))),values(anyM.parts.tech))...)...))
				if !isempty(intersect(emC_arr,vcat(map(x -> [x,getDescendants(x,anyM.sets[:C],true)...],allSt_arr)...)))
					# get all storage variables where storage losses can lead to emissions
					stVar_dic = Dict((string(st) |> (y -> Symbol(uppercase(y[1]),y[2:end]))) => getAllVariables(st,anyM, filterFunc = x -> x.C in emC_arr || x.Te in emTe_arr) for st in (:stIn,:stOut))
					stLvl_df = getAllVariables(:stLvl,anyM, filterFunc = x -> x.C in emC_arr)

					# loop over relevant storage technologies to obtain loss vallues
					tSt_arr = unique(stLvl_df[!,:Te])
					for tInt in tSt_arr
						part = anyM.parts.tech[sysSym(tInt,anyM.sets[:Te])]
						# add expression quantifying storage losses for storage in- and and output
						for st in keys(stVar_dic)
							stVar_df = stVar_dic[st]
							stVar_df = matchSetParameter(filter(x -> x.Te == tInt,stVar_df),part.par[Symbol(:eff,st)],anyM.sets)
							stVar_df[!,:var] = stVar_df[!,:var] .* (1 .- stVar_df[!,:val])
							select!(stVar_df,Not(:val))
							allVar_df = vcat(allVar_df,stVar_df)
						end

						# add expression quantifying storage losses for storage discharge
						if :stDis in keys(part.par)
							sca_arr = getResize(stLvl_df,anyM.sets[:Ts],anyM.supTs)
							stLvl_df = matchSetParameter(filter(x -> x.Te == tInt,stLvl_df),part.par[:stDis],anyM.sets)
							stLvl_df[!,:var] = stLvl_df[!,:var] .* (1 .- (1 .- stLvl_df[!,:val]) .^ sca_arr)
							select!(stLvl_df,Not(:val))
							allVar_df = vcat(allVar_df,stLvl_df)
						end
					end
				end

				# add expressions for exchange losses
                if :exc in keys(anyM.parts.exc.var)
					exc_df = getAllVariables(:exc,anyM, filterFunc = x -> x.C in emC_arr)
					exc_df = getExcLosses(exc_df,anyM.parts.exc.par,anyM.sets)
					# exchange losses are equally split between import and export region
					filter!(x -> x.loss != 0.0,exc_df)
					if !isempty(exc_df)
		                exc_df[!,:var] = exc_df[!,:var] .* exc_df[!,:loss] .* 0.5
						exc_df = rename(combine(groupby(vcat(exc_df,rename(exc_df,:R_from => :R_to,:R_to => :R_from)),filter(x -> x != :R_to,intCol(exc_df))),:var => (x -> sum(x)) => :var),:R_from => :R_dis)
						# dimensions not relevant for exchange are set to 0
						exc_df[!,:Te] .= 0; exc_df[!,:Ts_expSup] .= 0; exc_df[!,:M] .= 0
						allVar_df = vcat(allVar_df,exc_df)
					end
				end
			end

			allVar_df = matchSetParameter(allVar_df,anyM.parts.lim.par[:emissionFac],anyM.sets)
		end

		if !isempty(allVar_df)
			allVar_df[!,:var] = allVar_df[!,:val]  ./ 1e6 .* allVar_df[!,:var]
			select!(allVar_df,Not(:val))
		end
	end

	if !(va in (:capaConv,:capaStIn,:capaStOut,:capaStSize,:insCapaConv,:insCapaStIn,:insCapaStOut,:insCapaStSize,:expConv,:expStIn,:expStOut,:expStSize)) && !isempty(allVar_df) && reflectRed
		allVar_df[!,:var] .= allVar_df[!,:var] .* anyM.options.redStep
	end

	return filter(filterFunc,allVar_df)
end

# ! replaces original carriers in var_df with all leafes connected to respective carrier (and itself) and flattens it
function replCarLeafs(var_df::DataFrame,c_tree::Tree;cCol::Symbol=:C,noLeaf::Array{Int,1} = Int[])

	cToLeafs_dic = Dict(x => filter(y -> isempty(c_tree.nodes[y].down) || y in noLeaf,[x,getDescendants(x,c_tree,true)...]) for x in unique(var_df[!,cCol]))
	var_df[!,:C] = map(x -> cToLeafs_dic[x],var_df[!,cCol])
	var_df = flatten(var_df,:C)

	return var_df
end

# ! returns array of technologies and respective dispatch variables relevant for input carrier
function getRelTech(c::Int,tech_dic::Dict{Symbol,TechPart},c_tree::Tree)

	techSym_arr = collect(keys(tech_dic))
	relTech_arr = Array{Tuple{Symbol,Symbol},1}()
	for tSym in techSym_arr
		addConvTech_arr = intersect((:use,:gen),filter(y -> c in tech_dic[tSym].carrier[y], collect(keys(tech_dic[tSym].carrier))))
		if isempty(c_tree.nodes[c].down) # actual dispatch variables for storage only exists for carriers that are leaves
			addStTech_arr = intersect((:stExtIn,:stExtOut),filter(y -> c in union(map(z -> union([z],getDescendants(z,c_tree,true)),tech_dic[tSym].carrier[y])...), collect(keys(tech_dic[tSym].carrier))))
		else
			addStTech_arr = Array{Tuple{Int,Symbol},1}()
		end
		union(addConvTech_arr,addStTech_arr) |> (y -> append!(relTech_arr,collect(zip(fill(tSym,length(y)),y))))
	end

	return relTech_arr
end

#endregion
