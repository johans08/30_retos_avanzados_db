-- ********
-- Inserts
-- ********

INSERT INTO TipoMoneda (Descripcion) VALUES 
('CRC'),   -- Colón costarricense
('USD');   -- Dólar estadounidense


INSERT INTO TipoCambio (TipoCambio, Porcentaje, IdTipoMoneda) VALUES 
('CRC a USD', 0.0019, 1),  -- 1 CRC = 0.0019 USD
('USD a CRC', 530.00, 2);  -- 1 USD = 530 CRC


INSERT INTO Banco (Nombre) VALUES 
('Banco Nacional'),     -- IdBanco = 1
('BAC Credomatic');     -- IdBanco = 2


INSERT INTO Clientes (Cedula, Nombre, Apellido, FechaNacimiento) VALUES 
(101, 'Carlos', 'Soto', '1985-02-10'),   -- Cedula = 101
(102, 'Andrea', 'Mora', '1990-07-25');   -- Cedula = 102


INSERT INTO Estado (Estado) VALUES 
('Exitosa'),   -- IdEstado = 1
('Fallida'),   -- IdEstado = 2
('Pendiente'); -- IdEstado = 3


INSERT INTO ComisionesBancarias (Comision, Porcentaje, IdBanco) VALUES 
('Comisión Básica', 0.5, 1),  -- 0.5% para Banco Nacional
('Comisión Premium', 0.3, 2); -- 0.3% para BAC Credomatic


INSERT INTO ReglaTransaccion (Detalle, RangoMinimo, RangoMaximo, IdBanco) VALUES 
('Transferencias estándar nacionales', 1000.00, 1000000.00, 1),
('Transferencias internacionales', 10000.00, 5000000.00, 2);


-- Cliente 101: Banco Nacional (CRC)
INSERT INTO CuentasBancarias (IdCuentaBancaria, DetalleCuenta, Saldo, Cedula, IdBanco, IdTipoMoneda)
VALUES 
('C001', 'Cuenta CRC Carlos', 150000.00, 101, 1, 1);  -- CRC

-- Cliente 102: BAC Credomatic (USD)
INSERT INTO CuentasBancarias (IdCuentaBancaria, DetalleCuenta, Saldo, Cedula, IdBanco, IdTipoMoneda)
VALUES 
('C002', 'Cuenta USD Andrea', 300.00, 102, 2, 2);  -- USD





-- Ejecucion de procedimientos almacenados


-- Caso 01: Transferencia exitosa:
EXEC sp_transferirFondos @IdCuentaOrigen = 'C001', @IdCuentaDestino = 'C002', @Monto = 50000.00;

-- Caso 02: Transferencia fallida por saldo insuficiente:
EXEC sp_transferirFondos @IdCuentaOrigen = 'C001', @IdCuentaDestino = 'C002', @Monto = 9999999.00;

-- Caso 03: Transferencia fallida por cuenta inexistente:
EXEC sp_transferirFondos @IdCuentaOrigen = 'X001', @IdCuentaDestino = 'C002', @Monto = 5000.00;


-- Ejecucion de vistas
SELECT * FROM vw_TransaccionesDetalle;
