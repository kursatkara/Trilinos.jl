using Trilinos
using Test
using MPI

if Test.get_testset_depth() == 0
  MPI.Init()
end

lows_factory = Thyra.BelosLinearOpWithSolveFactory(Float64)
pl = Teuchos.ParameterList()
Thyra.setParameterList(lows_factory, pl)

Thyra.setVerbLevel(lows_factory, Teuchos.VERB_NONE)
lows = Thyra.createOp(lows_factory)

comm = Teuchos.MpiComm(MPI.CComm(MPI.COMM_WORLD))
const n = 20
rowmap = Tpetra.Map(n, 0, comm)
A = Tpetra.CrsMatrix(spdiagm(0 => ones(n)),rowmap)

rangespace = Thyra.tpetraVectorSpace(Tpetra.getRangeMap(A))
domainspace = Thyra.tpetraVectorSpace(Tpetra.getDomainMap(A))
A_thyra = Thyra.tpetraLinearOp(rangespace, domainspace, A)
Thyra.initializeOp(lows_factory, A_thyra, lows)

x = Tpetra.Vector(Tpetra.getDomainMap(A))
b = Tpetra.Vector(Tpetra.getRangeMap(A))
Tpetra.randomize(x)

# Test apply
Tpetra.apply(A,x,b)

x_th = Thyra.tpetraVector(domainspace, x)
b_th = Thyra.tpetraVector(rangespace, b)

status = Thyra.solve(lows, Thyra.NOTRANS, b_th, x_th)

# high-level interface
lows2 = Thyra.LinearOpWithSolve(A)
x2 = lows2 \ b

# Check result
bv = Tpetra.device_view(b)
xv = Tpetra.device_view(x2)
@test length(LinearIndices(bv)) == length(LinearIndices(xv))
for (bi,xi) in zip(bv,xv)
  @test bi ≈ xi
end

if Test.get_testset_depth() == 0
  MPI.Finalize()
end
