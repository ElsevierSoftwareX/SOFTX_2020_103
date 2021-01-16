using Base.Threads, CSV, Dates, LinearAlgebra, Requires
using MathOptInterface, Reexport, Statistics, PyCall, SparseArrays
using DataFrames, JuMP

pyimport_conda("networkx","networkx")
pyimport_conda("matplotlib.pyplot","matplotlib")
pyimport_conda("plotly","plotly")

include("src/objects.jl")
include("src/tools.jl")
include("src/modelCreation.jl")

include("src/optModel/technology.jl")
include("src/optModel/exchange.jl")
include("src/optModel/system.jl")
include("src/optModel/cost.jl")
include("src/optModel/other.jl")
include("src/optModel/objective.jl")


include("src/dataHandling/mapping.jl")
include("src/dataHandling/parameter.jl")
include("src/dataHandling/readIn.jl")
include("src/dataHandling/tree.jl")
include("src/dataHandling/util.jl")



# fange mit mustRun implementierug an 
# update reporting


anyM = anyModel("examples/demo","examples/results", objName = "test")
createOptModel!(anyM)
setObjective!(:cost,anyM)

using Gurobi
set_optimizer(anyM.optModel, Gurobi.Optimizer)
optimize!(anyM.optModel)

printIIS(anyM)



# TODO 1) warum keine fehlermeldung mit ratio problem? 2) warum problem mit ratio allgemein, sollte kein widerspruch sein und funktioniert ja auch wo anders

tSym = :heatpump
tInt = sysInt(tSym,anyM.sets[:Te])
part = anyM.parts.tech[tSym]
prepTech_dic = prepSys_dic[:Te][tSym]

eSym = :gas1
eInt = sysInt(eSym,anyM.sets[:Exc])
part = anyM.parts.exc[eSym]
prepExc_dic = prepSys_dic[:Exc][eSym]



getAllVariables(:emission,anyM)

anyM = anyModel()
objName = "bla"
csvDelim = ","
decomm = :decomm
interCapa = :linear
supTsLvl = 0
shortExp = 10
redStep = 1.0
emissionLoss = true
reportLvl = 2
errCheckLvl = 1
errWrtLvl = 1
coefRng = (mat = (1e-2,1e5), rhs = (1e-2,1e2))
scaFac = (capa = 1e1, insCapa = 1e2, dispConv = 1e3, dispSt = 1e4, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e2, obj = 1e0)
bound = (capa = NaN, disp = NaN, obj = NaN)
avaMin = 0.01
checkRng = NaN
inDir = "examples/demo"
outDir = "results"




set_optimizer(anyM.optModel,Gurobi.Optimizer)
optimize!(anyM.optModel)


printObject(anyM.parts.exc.cns[:excCapa], anyM, fileName = "bla2")


using AnyMOD
  