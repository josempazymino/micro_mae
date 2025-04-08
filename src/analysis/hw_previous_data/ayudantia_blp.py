# -*- coding: utf-8 -*-
"""
Created on Wed Oct 23 14:05:53 2024

@author: josem
"""

import pyblp
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

pyblp.options.digits = 2
pyblp.options.verbose = True

############################
############################

# Paso 0: Cargar datos e inspeccionar base
product_data = pd.read_csv(pyblp.data.NEVO_PRODUCTS_LOCATION)

# Cuantas firmas?
nfirma = product_data.firm_ids.nunique()

# Cuantas firmas?
nfirma = product_data.firm_ids.nunique()

# Cuantos marcas por firma?
product_data.groupby(['firm_ids']).agg({'brand_ids':'nunique'}).reset_index()

# Cuantos productos (firma x marca)
nproducto = product_data.brand_ids.nunique()

# Cuantas ciudades?
nciudades = product_data.city_ids.nunique()

# Cuantos trimestres?
ntri = product_data.quarter.nunique()

# Cuantos mercados (ciudades x trimestres)
nmercados = product_data.market_ids.nunique()

# Cual es la participacion del outside good?
outside_good = product_data.groupby(['market_ids', 'city_ids','quarter']).agg({'shares':'sum'}).reset_index()
outside_good['outside_good'] = 1 - outside_good['shares']

# Que firma es la mas importante?
firma_size = product_data.groupby(['firm_ids',
								   'market_ids']).agg({'shares':'sum'}).reset_index()

###############################################################################
###############################################################################

# Aca vamos a correr un BLP, similar a Nevo (2000) "A practitioner's guide to ..."
# En esta version inicial no incluimos data demografica

# 0. Preliminares:
	# Data tiene que incluir las siguientes columnas:
	# market_ids, product_ids, shares, prices,
	# demand_instruments0..X (instrumentos excluidos para la estimacion de demanda)
	# ademas de precios, incluir otras caracteristicas de productos

# 1. Especificamos la parte linear del modelo
# Absorb se refiere a que vamos a usar FE a nivel de producto,
# por eso no se usa una constante en la formulacion,
# entonces se la quitamos (0) y solo ponemos precios
X1_formulation = pyblp.Formulation('0 + prices', absorb='C(product_ids)')

# 2. Especificamos la parte no lineal del modelo
# En nuestro caso vamos a permitir que exista varianza en la constante,
# en precios y en las caracteristicas sugar y mushy
X2_formulation = pyblp.Formulation('1 + prices + sugar + mushy')

# 3. Concatemos ambas formulaciones
product_formulations = (X1_formulation, X2_formulation)
#product_formulations

# 4. Definimos que tipo de integracion queremoswhat type of integration
mc_integration = pyblp.Integration('halton', size=20, specification_options={'seed': 0})
#mc_integration

# 5. Seteamos todo el problema
mc_problem = pyblp.Problem(product_formulations,
			product_data,
			integration=mc_integration)
#mc_problem

# 6. Definimos que tipo de optimizacion vamos a usar
bfgs = pyblp.Optimization('l-bfgs-b', {'gtol': 1e-4})
#bfgs

# 7. Aqui ya resolvemos el problema. El valor de sigma ya automaticamente
# restringe los valores fuera de la diagonal
results1 = mc_problem.solve(sigma=np.eye((4)), optimization=bfgs)
results1

###############################
###############################

# Aqui incluimos data demografica

# Tengamos en cuenta que para cada mercado, deben existir Nsim filas identicas
# Osea, de la data demografica existente, ya se "samplearon" Nsim individuos por mercado
# La columna weights dice cuanto "pesa" cada individuo
# La columna nodes0, nodes1, ... corresponde a cada valor de v.
# Todo esto esta sampleado por market
agent_data = pd.read_csv(pyblp.data.NEVO_AGENTS_LOCATION)

#agent_data = agent_data[['market_ids','city_ids', 'quarter', 'income','income_squared', 'age', 'child']]
agent_formulation = pyblp.Formulation('0 + income + income_squared + age + child')

nevo_problem = pyblp.Problem(
    product_formulations,
    product_data,
    agent_formulation,
    agent_data
)

nevo_problem

# valores iniciales de sigma
initial_sigma = np.diag([0.3302, 2.4526, 0.0163, 0.2441])
# valores iniciales de matriz Pi
initial_pi = np.array([
  [ 5.4819,  0,      0.2037,  0     ],
  [15.8935, -1.2000, 0,       2.6342],
  [-0.2506,  0,      0.0511,  0     ],
  [ 1.2650,  0,     -0.8091,  0     ]])

tighter_bfgs = pyblp.Optimization('bfgs', {'gtol': 1e-5})
nevo_results = nevo_problem.solve(
    initial_sigma,
    initial_pi,
    optimization=tighter_bfgs,
    method='2s' # esto es cuantas etapas correr GMM (1s o 2s)
)

beta   = nevo_results.beta # x1
sigma  = nevo_results.sigma # var-cov matriz de x2
pi     = nevo_results.pi # matriz de x2 y demografia
xi     = nevo_results.xi # xi no obs de demanda
xi_fe  = nevo_results.xi_fe # 
xi_end = xi + xi_fe

###########################
###########################

# Con los resultados podemos crear los costos marginales implicitos por el modelo
# Asumiendo una matriz Omega sin valores fuera de la diagonal
costs = nevo_results.compute_costs()
plt.hist(costs, bins=50)
plt.legend(["Marginal Costs"])

# Notemos que podemos recuperar los valores de precios si hacemos
# Obtenemos el mismo precio que el que se encuentra en product_data
precio_check = nevo_results.compute_prices(costs = costs)

# Con los resultados podemos crear markups implicitos por el modelo
# Asumiendo una matriz Omega sin valores fuera de la diagonal
markups = nevo_results.compute_markups(costs=costs)
plt.hist(markups, bins=50)
plt.legend(["Markups"])

# Podemos crear HHI, Profits y Excedente del Consumidor
hhi = nevo_results.compute_hhi() # a nivel mercado
profits = nevo_results.compute_profits(costs=costs) # a nivel firma
cs = nevo_results.compute_consumer_surpluses() # a nivel mercado

##################
##################

#########################################
# CF1: FUSION ENTRE LAS FIRMAS 1 y 2 ####
#########################################

# Existen 2 formas de hacer un contrafactual relacionado a una fusion

# A. Modificando la columna firm_ids
#####################################

# Osea, donde haya un valor de 2, poner un 1
# Una fusion de 1 y 2
product_data['merger_ids'] = product_data['firm_ids'].replace(2, 1)

product_data_fake = product_data.copy()
product_data_fake['firm_ids'] = product_data_fake['merger_ids']

# Las matrices estan verticalmente concatenadas
ownership = pyblp.build_ownership(product_data=product_data)
ownership_cf1_v1 = pyblp.build_ownership(product_data=product_data_fake)

# Dado este nuevo vector firm_ids, podemos resolver la FONC y
# tener nuevos precios
prices_cf1_v1 = nevo_results.compute_prices(
    firm_ids=product_data['merger_ids'], 
    costs=costs
)

# Datos nuevos precios, podemos obtener nuevas participaciones
shares_cf1_v1 = nevo_results.compute_shares(prices_cf1_v1)
# Que van a cambiar el HHI
hhi_cf1_v1    = nevo_results.compute_hhi(
    firm_ids=product_data['merger_ids'],
    shares=shares_cf1_v1)
#plt.hist(hhi_cf1_v1 - hhi, bins=50);
#plt.legend(["Cambios en HHI"]);

# Y tambien podemos tener nuevos markups
markups_cf1_v1 = nevo_results.compute_markups(prices_cf1_v1, costs)
plt.hist(markups_cf1_v1 - markups, bins=50);
plt.legend(["Cambios en Markup"]);

# Y profits
profits_cf1_v1 = nevo_results.compute_profits(prices_cf1_v1, shares_cf1_v1, costs)
#plt.hist(profits_cf1_v1 - profits, bins=50);
#plt.legend(["Cambios en Profits"]);

# Y excedentes del consumidor
cs_cf1_v1 = nevo_results.compute_consumer_surpluses(prices_cf1_v1)
#plt.hist(cs_cf1_v1 - cs, bins=50);
#plt.legend(["Cambios en CS"]);

# B. Alternativamente podemos modificar Omega directamente
# (Nos deberia salir lo mismo!!!)
##########################################################

# Creamos una funcion que nos diga que se hagan 1 si tenemos productos de las firmas
# 1 y 2
def kappa_specification(f, g):
	# Si es el mismo, mantengo el valor 1
	if f == g:
		return 1
	else:
		if f ==1 and g == 2:
			return 0.5
		else:
			return 0
   # Si los productos pertenecen a los firm_ids de las firmas 1 y 2,
   # entonces pongo (fusion), de otro modo 0
   # OJO: NO TENDRIA PORQUE SER 1, podria ser entre 0 y 1
   # return 1 if  else 0

# Aca creo la otra version de la matriz
ownership_cf1_v2 = pyblp.build_ownership(product_data_fake, kappa_specification)

# Y volvemos a calcular todo
prices_cf1_v2 = nevo_results.compute_prices(
    ownership= ownership_cf1_v2,
    costs=costs
)

shares_cf1_v2 = nevo_results.compute_shares(prices_cf1_v2)

hhi_cf1_v2 = nevo_results.compute_hhi(
    shares=shares_cf1_v2
)

markups_cf1_v2 = nevo_results.compute_markups(prices_cf1_v2, costs)

profits_cf1_v2 = nevo_results.compute_profits(prices_cf1_v2, 
											shares_cf1_v2, costs)

cs_cf1_v2 = nevo_results.compute_consumer_surpluses(prices_cf1_v2)

###############################################################################
###############################################################################

##############################################################
# CF2: QUE PASA SI UNA FIRMA INCREMENTA SUS COSTOS MARGINALES
# (imaginemos firma 2)
##############################################################

# Creamos un nuevo vector de costos (contrafactual)
costs_cf2 = costs.copy()
costs_cf2[ product_data.firm_ids==2 ] = costs_cf2[ product_data.firm_ids==2 ]*1.25

# Creamos vector de precios nuevo y shares nuevas
precio_cf2_v1 = nevo_results.compute_prices(costs = costs_cf2)
shares_cf2_v1 = nevo_results.compute_shares(precio_cf2_v1)

# Alternativamente podemos usar el comando simulacion
# (este es un comando mas flexible)

# Primero se define la simulacion
cf2 = pyblp.Simulation(
    product_formulations = (pyblp.Formulation('0 + prices'),
							pyblp.Formulation('1 + prices + sugar + mushy')), 
    product_data = product_data, 
    beta = beta, 
    sigma = sigma, 
	pi = pi,
    agent_data = agent_data,
	agent_formulation = agent_formulation,
    xi = xi_end
)

# Luego se reemplaza para que se ejecute
cf22 = cf2.replace_endogenous(costs = costs_cf2, error_behavior = 'warn')

# Podemos ver que sale lo mismo!!!
# (asi que esta bien)
precio_cf2_v2 = cf22.compute_prices()
shares_cf2_v2 = cf22.compute_shares()

# Podemos calcular profits, cs, markups!!!!
markups_cf2 = cf22.compute_markups()
profits_cf2 = cf22.compute_profits()
cs_cf2      = cf22.compute_consumer_surpluses()

###############################################################################
###############################################################################

##############################################################
# CF3: Que pasa si en el mercado son mas sensibles al precio?
# El coeficiente Beta se hace mas negativo
##############################################################

# Primero se define la simulacion
cf3 = pyblp.Simulation(
    product_formulations = (pyblp.Formulation('0 + prices'),
							pyblp.Formulation('1 + prices + sugar + mushy')), 
    product_data = product_data, 
    beta = beta*1.2, 
    sigma = sigma, 
	pi = pi,
    agent_data = agent_data,
	agent_formulation = agent_formulation,
    xi = xi_end
)

# Luego se reemplaza para que se ejecute
cf33 = cf3.replace_endogenous(costs = costs, error_behavior = 'warn')

# Obtenemos precios y cantidades
precio_cf3 = cf33.compute_prices()
shares_cf3 = cf33.compute_shares()

# Podemos calcular profits, cs, markups!!!!
markups_cf3 = cf33.compute_markups()
profits_cf3 = cf33.compute_profits()
cs_cf3      = cf33.compute_consumer_surpluses()

###############################################################################
###############################################################################

##############################################################
# CF4: Que pasa si eliminamos un producto?
##############################################################

# Borremos
DROP = 'F1B06'
# Copiamos para no afectar data original
product_data_cf4 = product_data.copy()
# Borramos producto de la base
product_data_cf4 = product_data_cf4[product_data_cf4['product_ids'] != DROP]

xi_end_cf4 = xi_end
xi_end_cf4 = xi_end_cf4[product_data['product_ids'] != DROP]

beta_cf4 = [b for b, label in zip(nevo_results.beta, nevo_results.beta_labels)
            if label != f"product_ids['{DROP}']"]
costs_cf4 = costs[product_data['product_ids'] != DROP]

# Simulate counterfactual
cf4  = pyblp.Simulation(
	product_formulations = (pyblp.Formulation('0 + prices'),
	pyblp.Formulation('1 + prices + sugar + mushy')), 
	product_data = product_data_cf4,
	beta=beta_cf4, 
	sigma = sigma,
	pi = pi,
	agent_data = agent_data,
	agent_formulation = agent_formulation,
	xi=xi_end_cf4)
cf44 = cf4.replace_endogenous(costs=costs_cf4)



