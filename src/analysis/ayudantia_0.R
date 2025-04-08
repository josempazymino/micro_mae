# Ejemplo Minimo Tarea 1
# Hacer contrafactuales
# Vamos a resolver un modelo de Cournot bajo N

library(nleqslv)

################################################################################
################################################################################

# Demanda inversa
# P = A - B * Q

# mc1 = c1
# mc2 = c2

################################################################################
################################################################################

# Define de manera general la curva de demanda inversa
pp <- function(A, B, Q){A-B*Q}

# Solucion del modelo (igualamos sistema de FOC)
foc <- function(A, B, mcvector, omega,  qvector){
  
  # A = scalar
  # B = scalar
  # mcvector = vector de costos marginales de Nx1
  # qvector  = vector de cantidades de cada firma de Nx1
  
  # Cuantas firmas?
  nn = NROW(qvector)
  
  # Fijamos la funcion de demanda inversa respecto de algunos valores
  pp0 <- function(Q) pp(A, B, Q)
  
  # Derivada de P wrt Q
  derpq = -B
  
  # Creamos vector de unos
  vones <- matrix(1, nn, 1)
  
  # Escribimos la condiciones de primer orden
  # MR - MC = 0 para cada firma
  zzero = (vones * pp0(sum(qvector0)) ) + (omega * derpq) %*% qvector - mcvector
  
  return(zzero)
  
  
}


################################################################################
################################################################################

# Definimos algunos parametros
A  <- 1
B  <- 1
NN <- 2
mcvector0 <- matrix(c(0.1, 0.1),NN,1)
qvector0  <- matrix(0.1,NN,1)
omega     <- diag(1, NN, NN)

# prueba
#foc(A, B, mcvector0, omega, qvector0)

# prueba0
foc0 <- function(qvector) foc(A, B, mcvector0, omega, qvector)

# Vemos que el programa corre
try0 = matrix( c(0,0.2)  ,NN,1)
foc0(try0)

# Permitimos la minimizacion
sol0 = nleqslv(try0, foc0, control=list(ftol=.0001, allowSingular=TRUE),  method = "Broyden")


