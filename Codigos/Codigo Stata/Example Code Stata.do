* Example Code using ENAHO and Censo Educativo 2016- Jonatan Amaya

clear all
clear
set more off


* Choose PC

if "`c(username)'" == "J. Amaya" { 				/* PC */
	global rootdata "C:\Users\jony1\Documents\GitHub\Pruebas\data"
	global rootoutput "C:\Users\jony1\Documents\GitHub\Pruebas\output"
}
else if "`c(username)'" == "Otro usuario" {			/* PC Otro */
	global root "C:\Users\username\root"
}




*************************************************************************
********************************* ENAHO *********************************
*************************************************************************



* Se genera la base de datos utilizando la ENAHO 

use enaho01a-2019-300.dta, clear //Modulo de Educacion
keep conglome vivienda hogar codperso estrato p301a p301b p301c ubigeo //Se obtiene variable escolaridad, area.
merge 1:1 conglome vivienda hogar codperso using "$rootdata/enaho01a-2019-500.dta", keepus (ocupinf p512a p524a1 p513a1) //Se fusiona con el Modulo de Empleo e ingresos. Se obtiene variable tamaño_empresa, informal, experiencia_laboral y salario
drop _merge
merge 1:1 conglome vivienda hogar codperso using "$rootdata/enaho01-2019-200.dta", keepus (p207 p208a) //Se fusiona con el Modulo Caracteristicas de los miembros del hogar. Se obtiene variable sexo y edad 
keep if _merge==3
drop _merge
keep if p208a>14 //Nos quedamos con la PEA


* Se generan las variables

* Dummy de sexo
gen sexo=1 if p207==1 
replace sexo=0 if p207==2

* Nivel de escolaridad
recode p301a (1/3=0) (4/5=6) (6/9=11) (10=16) (.=.), gen(nivelprevio) 
egen suma=rowtotal(p301b p301c)
gen escolaridad= suma + nivelprevio

* Edad
gen edad = p208a 

* Area
gen area=estrato //Se genera la variable AREA
recode area (1/5=1) (6/8=0)
label define area_etiquetas 1 "Urbano" 0 "Rural"
label values area area_etiquetas

* Informalidad
gen informal=1 if ocupinf==1 //Generar dummy de INFORMALIDAD, var hombre sera 1 si es informal y 0 si es formal
replace informal=0 if ocupinf==2

* Tamaño de la empresa
recode p512a (1/2=1) (3/4=2) (5=3) (.=.), gen(tamaño_empresa) //Generar TAMAÑO DE LA EMPRESA
label define etiqueta_empresa 1 "Pequeña empresa" 2 "Mediana empresa" 3 "Gran empresa" 
label values tamaño_empresa etiqueta_empresa

* Salario y su logaritmo
gen salario=p524a1 //Generar variable de SALARIO y su logaritmo
gen lnsalario=ln(salario)

* Experiencia
gen experiencia_laboral=p513a1 //Generar variable experiencia laboral
gen experiencia_potencial=edad - escolaridad - 6 //Generar variable experiencia potencial

* Departamento
gen departamento=substr(ubigeo,1,2) //Generar variable departamento
destring departamento, replace
label define departamentos 1 "Amazonas" 2 "Ancash" 3 "Apurimac" 4 "Arequipa" 5 "Ayacucho" 6 "Cajamarca" 7 "Callao" 8 "Cusco" 9 "Huancavelica" 10 "Huanuco" 11 "Ica" 12 "Junin" 13 "La Libertad" 14 "Lambayeque" 15 "Lima" 16 "Loreto" 17 "Madre de Dios" 18 "Moquegua" 19 "Pasco" 20 "Piura" 21 "Puno" 22 "San Martin" 23 "Tacna" 24 "Tumbes" 25 "Ucayali"
label values departamento departamentos

keep escolaridad area tamaño_empresa informal experiencia_laboral experiencia_potencial sexo edad lnsalario departamento salario
drop if missing(lnsalario) 
save "$rootdata/base.dta", replace




* Deteccion de heterocedasticidad por departamento

local i=1
while `i' {
	keep if departamento==`i'
	quietly reg lnsalario escolaridad area tamaño_empresa informal experiencia_laboral experiencia_potencial
	vif
	hettest
	test escolaridad area tamaño_empresa informal experiencia_laboral experiencia_potencial
	use "$rootdata/base.dta", clear
local i=`i'+1
if `i'==26 continue, break	
}


* Test de ratio de verosimilitud por departamento

local i=1
while `i' {
	keep if departamento==`i'
	quietly reg lnsalario escolaridad area tamaño_empresa informal experiencia_laboral experiencia_potencial
	estimates store fmodel
	qui reg lnsalario escolaridad area tamaño_empresa informal experiencia_laboral 
	estimates store nmodel 
	lrtest fmodel nmodel 
	use "$rootdata/base.dta", clear
local i=`i'+1
if `i'==26 continue, break	
}



* Regresiones por departamento, se almacenan los resultados
local i=1
while `i' {
	keep if departamento==`i'
	reg lnsalario escolaridad area tamaño_empresa informal experiencia_laboral experiencia_potencial, vce(robust)
	estimates store reg_department_`i'
	use "$rootdata/base.dta", clear
	local i=`i'+1
	if `i'==24 continue, break	
}




* Se obtiene el promedio de salarios por departamento 
collapse (mean) salario , by(departamento)
save "$rootdata/base_mapa.dta", replace



* Grafico de barras
sum salario
local mean_salario=r(mean) 

graph hbar salario, ///
		over(departamento, sort(desempleo) descending label(labsize(vsmall))) ///
		blabel(total, format(%10.0fc) size(vsmall) color (red)) yline(`mean_salario') ///
		title("Salario promedio por departamento", size(medium)) ///
		subtitle ("País: Perú") ///
		ytitle("Salario (S/.)") ylabel(,nogrid) subtitle("Año 2019") ///
		graphregion(color(white)) ///
		note ("Fuente: Elaboracion propia - INEI 2019")
		
graph export "$rootoutput/graficoBarras.png", as(png) replace 	


* Mapa

//Se generan los datos geograficos
grmap, activate

shp2dta using "DEPARTAMENTOS_inei_geogpsperu_suyopomalia.shp", database(perumapa) coordinates(perucoord) genid(id) genc(centro) replace

use "perumapa", clear
gen departamento=OBJECTID
save "perumapa.dta", replace

use "perumapa.dta", clear
merge 1:m departamento using "$rootdata/base_mapa", nogen 
save "$rootdata/base_salario.dta", replace

use "$rootdata/base_salario.dta", clear //Se guarda en una base de datos


preserve
generate label = NOMBDEP
keep id x_c y_c label
gen length = length(label)
save "$rootdata/labels.dta", replace
restore

use "$rootdata/base_salario.dta", clear
//Se genera el mapa de la tasa de desempleo por departamento
spmap salario using "$rootdata/perucoord.dta", id(id) ocolor(black) fcolor(Blues) ///
	label(data("labels.dta") x(x_c) y(y_c) ///
		    label(label) size(vsmall) position(0 6) length(21)) ///
	title("Salario promedio en el Perú") ///
	subtitle("2019") ///
	legend (pos (7) title ("Rangos de salarios", size (*0.5))) ///
	note("Fuente: Elaboracion propia - INEI 2019")

graph export "$rootoutput/mapa.png", as(png) name ("Graph") replace










*************************************************************************
*************************** Censo Educativo *****************************
*************************************************************************


* Estado de sala de profesores

clear
import dbase using "$rootdata/Plocal_s300.dbf", case(lower)
keep if cuadro=="P302"
gen numSalaProfBuenEstado = p300_1 if p300_esp=="Sala de profesores"
egen numSalaProfMalEstado= rowtotal(p300_4 p300_7) if p300_esp=="Sala de profesores"


keep if p300_esp=="Sala de profesores"
keep codlocal numSalaProfBuenEstado numSalaProfMalEstado
gen year_censoedu=2016
gen year_endo=2016
save "$rootdata/censo2016_salaprofesores.dta", replace




* Número de secciones

clear
import dbase using "$rootdata/Secciones.dbf", case(lower)


* primaria y secundaria
keep if niv_mod=="B0" | niv_mod=="F0"
* publica
keep if ges_dep=="A1" | ges_dep=="A2" | ges_dep=="A3" | ges_dep=="A4"


* Solo turno mañana

* Se genera una variable int de los turnos de la escuela
gen int tipdato_int = real(tipdato)

* Se busca si existe una observación con tipdato_int mayor a 1 por escuela, en ese caso se empieza a contar. Entonces, si multiples_turnos es mayor a 1, habrá más de 1 turno en la escuela correspondiente
bysort cod_mod: egen multiples_turnos = total(tipdato_int > 1)

* Nos quedamos con los estudiantes pertenecientes a escuelas con un solo turno
drop if multiples_turnos >= 1




keep cod_mod niv_mod anexo 

gen year_censoedu=2016
save "$rootdata/censo2016_secciones.dta", replace


















	