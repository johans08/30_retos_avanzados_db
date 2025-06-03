-- Inserts base de datos

-- Estados de movimientos
INSERT INTO Estados (Estado) VALUES ('Ingreso');
INSERT INTO Estados (Estado) VALUES ('Salida');
INSERT INTO Estados (Estado) VALUES ('Transferencia');

-- Almacenes
INSERT INTO Almacenes (Nombre, Ubicacion) VALUES ('Almacén Central', 'San José');
INSERT INTO Almacenes (Nombre, Ubicacion) VALUES ('Sucursal Norte', 'Heredia');
INSERT INTO Almacenes (Nombre, Ubicacion) VALUES ('Sucursal Sur', 'Cartago');

-- Productos
INSERT INTO Productos (CodigoSKU, Nombre, Descripcion) VALUES ('SKU001', 'Laptop Dell XPS', 'Laptop 16GB RAM, SSD 512GB');
INSERT INTO Productos (CodigoSKU, Nombre, Descripcion) VALUES ('SKU002', 'Mouse Logitech', 'Mouse inalámbrico con Bluetooth');
INSERT INTO Productos (CodigoSKU, Nombre, Descripcion) VALUES ('SKU003', 'Teclado Mecánico', 'Teclado retroiluminado RGB');

-- Inventario inicial
INSERT INTO Inventarios (IdAlmacen, IdProducto, Cantidad) VALUES (1, 1, 50); -- Almacén Central, Laptop
INSERT INTO Inventarios (IdAlmacen, IdProducto, Cantidad) VALUES (1, 2, 100); -- Almacén Central, Mouse
INSERT INTO Inventarios (IdAlmacen, IdProducto, Cantidad) VALUES (2, 3, 30); -- Sucursal Norte, Teclado

-- Movimientos: Ingreso, Salida, Transferencia
-- Ingreso: Mouse a Sucursal Sur
INSERT INTO Movimientos (IdProducto, AlmacenDestino, Cantidad, IdEstado)
VALUES (2, 3, 25, 1); -- Estado: Ingreso

-- Salida: 10 teclados de Sucursal Norte
INSERT INTO Movimientos (IdProducto, AlmacenOrigen, Cantidad, IdEstado)
VALUES (3, 2, 10, 2); -- Estado: Salida

-- Transferencia: 20 laptops de Central a Sucursal Norte
INSERT INTO Movimientos (IdProducto, AlmacenOrigen, AlmacenDestino, Cantidad, IdEstado)
VALUES (1, 1, 2, 20, 3); -- Estado: Transferencia



-- EXEC de procedimientos almacenados

-- Ingreso de 15 teclados a Sucursal Sur
EXEC RegistrarMovimiento @IdProducto = 3, @Cantidad = 15, @IdEstado = 1, @AlmacenDestino = 3;

-- Salida de 5 mouses desde Sucursal Sur
EXEC RegistrarMovimiento @IdProducto = 2, @Cantidad = 5, @IdEstado = 2, @AlmacenOrigen = 3;

-- Transferencia de 10 laptops desde Sucursal Norte a Almacén Central
EXEC RegistrarMovimiento @IdProducto = 1, @Cantidad = 10, @IdEstado = 3, @AlmacenOrigen = 2, @AlmacenDestino = 1;

-- Intento de salida con stock insuficiente
EXEC RegistrarMovimiento @IdProducto = 1, @Cantidad = 9999, @IdEstado = 2, @AlmacenOrigen = 2;



Select * FROM Vista_StockActual;
Select * FROM Vista_MovimientosDetalle;