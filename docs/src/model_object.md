```@raw html
<style>
table.tabelle2 td {
  padding-left: 0.57em;
  padding-right: 0.57em;
  border-right: solid 1px;
  border-color: #dbdbdb;
  font-size: small;
}
ul.liste {
  list-style-position: outside;
  padding-left: 1em;
  margin-left: 0em;
  margin-top: 0em;
  white-space: nowrap;
  display:inline-block;
  text-align: left;
}
</style>
```
# Model object

```julia
anyModel(inDir::Union{String,Array{String,1}},outDir::String; kwargs)
```

* `inDir::Union{String,Array{String,1}}`: directory of input files, also allows for provide multiple directories via an array
* `outDir::String`: directory of output files are written to

sets, parts

report

optModel, hier auch verweis auf erweiterbar

lock, supTs, cInfo

### Optional arguments

```@raw html
<table class="tabelle2">
<tbody>
<tr>
<td><strong>argument</strong></td>
<td><strong>explanation</strong></td>
<td><strong>default</strong></td>
<td style="border-right:none"><strong>group</strong></td>
</tr>



<tr>
<td><code>objName</code></td>
<td>
<ul class="liste">
<li>internal name of the model object</li>
<li>added to the name of output files and printed during reporting</li>
</ul>
</td>
<td><code>""</code></td>
<td rowspan="2"; style="border-right:none">data handling</td>
</tr>
<tr>
<td><code>csvDelim</code></td>
<td>
<ul class="liste">
<li>specifies the delimiter used within the read-in csv files</li>
</ul>
</td>
<td><code>","</code></td>
</tr>

<tr>
<td><code>shortExp</code></td>
<td>
<ul class="liste">
<li>intervall in years between steps of capacity expansion</li>
</ul>
</td>
<td><code>10</code></td>
<td rowspan="5"; style="border-right:none">model generation</td>
</tr>
<tr>
<td><code>supTsLvl</code></td>
<td>
<ul class="liste">
<li>depth in the tree of time-steps that defines the superordinate dispatch level (usually years)</li>
</ul>
</td>
<td><code>0</code></td>
<tr>
<td><code>redStep</code></td>
<td>
<ul class="liste">
<li>scales down energy quantities within the model, relevant when working <br> with reduced time-series</li>
</ul>
</td>
<td><code>1.0</code></td>
</tr>

<tr>
<td><code>decomm</code></td>
<td>
<ul class="liste">
<li>controlls if the model performs endogenous decommissioning, see <a href="https://arxiv.org/abs/2004.10184">Göke (2020)</a> for details</li>
<li>available options are:
<ul style="margin-top:0px">
<li style="margin-top:0px"><code>decomm</code>: capacities are decommissioned endogenously, once decommissioned <br> capacities cannot be put into operation again </li>
<li><code>recomm</code>: no endogenous decommissioning, operated capacities equal installed capacities</li>
<li><code>none</code>: capacities are decommissioned endogenously and can be put back into operation</li>
</ul>
</ul>
</ul>
</td>
<td><code>:decomm</code></td>
</td>
</tr>

<tr>
<td><code>interCapa</code></td>
<td>
<ul class="liste">
<li>capacity expansion can be modelled at a resolution less detailed than yearly, this option <br> determines how capacities are distributed among the subsequent years in this case</li>
<li>available options are:
<ul style="margin-top:0px">
<li style="margin-top:0px"><code>linear</code>:  expansion is equally distributed among years resulting in a linear increase</li>
<li><code>none</code>: all expansion occurs in the first year</li>
</ul>
</ul>
</ul>
</td>
<td><code>:linear</code></td>
</td>
</tr>



<tr>
<td><code>reportLvl</code></td>
<td>
<ul class="liste">
<li>controls the frequency of writing updates to the console</li>
</ul>
</td>
<td><code>2</code></td>
</td>
<td rowspan="3"; style="border-right:none"> <a href="../error/#Error-handling">reporting</a> </td>
</tr>
<tr>
<td><code>errCheckLvl</code></td>
<td>
<ul class="liste">
<li>controls the frequency of checking for errors</li>
</ul>
</td>
<td><code>2</code></td>
</td>
</tr>
</tr>
<tr>
<td><code>errWrtLvl</code></td>
<td>
<ul class="liste">
<li>controls the frequency of writing to the report file</li>
</ul>
</td>
<td><code>1</code></td>
</tr>

<tr>
<td><code>avaMin</code></td>
<td>
<ul class="liste">
<li>availabilities smaller than this value are set to zero</li>
<li>avoids high coefficients in <a href="../constraints/#Conversion-capacity-restriction">conversion</a> and <a href="../constraints/#Storage-capacity-restriction">storage capacity restriction</a>, because availabilities <br> are inversed</li>
</ul>
</td>
<td><code>0.01</code></td>
<td rowspan="6"; style="border-right:none;border-bottom:none"> <a href="../performance/#Performance-and-stability">performance and stability</a> </td>
</tr>

<tr>
<td><code>emissionLoss</code></td>
<td>
<ul class="liste">
<li>determines if losses from exchange and self-discharge of storage are subject to emissions</li>
</ul>
</td>
<td><code>true</code></td>
</tr>


<tr>
<td><code>checkRng</code></td>
<td>
<ul class="liste">
<li>if set, reports all equations whose range exceeds the specified value</li>
</ul>
</td>
<td><code>NaN</code></td>
</tr>


<tr>
<td><code>scaFac</code></td>
<td colspan = "2">
<ul class="liste">
<li>scales different groups of variables within the model</li>
<li>see <a href="../performance/#Scaling">Column scaling</a> for details and defaults</li>
</ul>
</tr>

<tr>
<td><code>coefRng</code></td>
<td colspan = "2">
<ul class="liste">
<li>specifies the maximum range of coefficients in the matrix and right-hand side of the model's underlying <br> optimization problem</li>
<li>see <a href="../performance/#Scaling">Row scaling</a> for details and defaults</li>
</ul>
</td>
</td>
</tr>


<tr>
<td><code>bound</code></td>
<td colspan = "2">
<ul class="liste">
<li>sets external bounds for all capacities and dispatch variables (in GW) and for the objective value (in Mil. €)</li>
<li>see <a href="../performance/#Variable-limits">Variable limits</a> for details and defaults</li>
</ul>
</td>
</tr>
</tr>

</tbody>
</table>
```


### Graph styling

`graInfo`

graph::flowGraph
names::Dict{String,String}
colors::Dict{String,Tuple{Float64,Float64,Float64}}