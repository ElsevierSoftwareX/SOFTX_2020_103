# Parts

```@raw html
<p class="norm">
The <code>parts</code> field of the <a href="../api/#AnyMOD.anyModel"><code>anyModel</code></a> object structures the elements of a model's underlying optimization problem. Each of these parts has again three fields:
<ul>
<li> <code>par::Dict{Symbol,ParElement}</code> &#8594; <a href="../parameter_overview">parameter</a></li>
<li> <code>var::Dict{Symbol,DataFrame}</code> &#8594; <a href="../variables">variables</a></li>
<li> <code>cns::Dict{Symbol,DataFrame}</code> &#8594; <a href="../constraints">constraints</a></li>
</ul>
</p>
```


### Technology

```@raw html
<p class="norm">
The <a href="../api/#AnyMOD.TechPart"><code>part</code></a> for technologies is accessed via <code>modelObject.parts.tech[:techName]</code>. These objects include all expansion and dispatch related elements for the respective technology. Technology parts have additional fields to store information specific to technologies.
</p>
```

### Exchange

```@raw html
<p class="norm">
The <a href="../api/#AnyMOD.OthPart"><code>part</code></a> object for exchange is accessed via <code>modelObject.parts.exc</code>. It includes all model elements relating to the exchange of energy carriers between regions. Exchange between two regions is enabled, if a value for the <a href="../parameter_list/#Residual-capacities-1">residual exchange capacity</a> parameter can be obtained between these two regions.
</p>
```

### Trade

```@raw html
<p class="norm">
For trade the <a href="../api/#AnyMOD.OthPart"><code>part</code></a> object is accessed via <code>modelObject.parts.trd</code>. It includes all model elements relating to buying and selling energy carriers from "outside" the model. Most importantly these are trade prices and variables for traded quantities.
</p>
```

### Balance

```@raw html
<p class="norm">
The <a href="../api/#AnyMOD.OthPart"><code>part</code></a> object for energy balances is accessed via <code>modelObject.parts.bal</code>. It is used to store all model elements relevant for the energy balance. For example, this includes the demand parameter, curtailment variables or the energy balance constraint itself.
</p>
```

### Limit

```@raw html
<p class="norm">
Model elements used to impose certain limits on model variables are stored in <code>modelObject.parts.lim</code>. These include <a href="../parameter_list/#Limits-on-expansion-and-capacity">limiting parameters</a> and the corresponding constraints enforcing these limits.
</p>
```

### Objective

```@raw html
<p class="norm">
The field <code>modelObject.parts.obj</code> gathers elements relating to the objective function of a model's underlying optimization problem. So far, the only available objective in AnyMOD is cost minimization and set by the <a href="../api/#AnyMOD.setObjective!"><code>setObjective!</code></a> function.
</p>
```

```julia
setObjective!(:costs, model_object)
```
An objective function has to be set after the optimization problem itself was created.
