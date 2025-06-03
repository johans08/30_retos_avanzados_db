-- Crear la base de datos
CREATE DATABASE dia03_transacciones_bancarias_con_asistencia_ACID;
GO

USE dia03_transacciones_bancarias_con_asistencia_ACID;
GO

-- Clientes
CREATE TABLE Clientes (
    Cedula INT NOT NULL PRIMARY KEY,
    Nombre VARCHAR(45) NOT NULL,
    Apellido VARCHAR(45) NOT NULL,
    FechaNacimiento DATE NOT NULL
);

-- Banco
CREATE TABLE Banco (
    IdBanco INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Nombre VARCHAR(45) NOT NULL UNIQUE
);

-- TipoMoneda
CREATE TABLE TipoMoneda (
    IdTipoMoneda INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Descripcion VARCHAR(45) NOT NULL UNIQUE
);

-- Estado
CREATE TABLE Estado (
    IdEstado INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Estado VARCHAR(45) NOT NULL
);

-- ComisionesBancarias
CREATE TABLE ComisionesBancarias (
    IdComision INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Comision VARCHAR(45) NOT NULL,
    Porcentaje DECIMAL(18, 2) NOT NULL,
    IdBanco INT NOT NULL,
    FOREIGN KEY (IdBanco) REFERENCES Banco(IdBanco)
);

-- ReglaTransaccion
CREATE TABLE ReglaTransaccion (
    IdReglaTransaccion INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Detalle VARCHAR(245) NOT NULL,
    RangoMinimo DECIMAL(18, 2) NOT NULL,
    RangoMaximo DECIMAL(18, 2) NOT NULL,
    IdBanco INT NOT NULL,
    FOREIGN KEY (IdBanco) REFERENCES Banco(IdBanco)
);

-- CuentasBancarias
CREATE TABLE CuentasBancarias (
    IdCuentaBancaria NVARCHAR(45) NOT NULL PRIMARY KEY,
    DetalleCuenta VARCHAR(45) NOT NULL,
    Saldo DECIMAL(18, 2) NOT NULL,
    Cedula INT NOT NULL,
    IdBanco INT NOT NULL,
    IdTipoMoneda INT NOT NULL,
    FOREIGN KEY (Cedula) REFERENCES Clientes(Cedula),
    FOREIGN KEY (IdBanco) REFERENCES Banco(IdBanco),
    FOREIGN KEY (IdTipoMoneda) REFERENCES TipoMoneda(IdTipoMoneda)
);

-- Transaccion
CREATE TABLE Transaccion (
    IdTransaccion INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Detalle VARCHAR(115) NOT NULL,
    FechaCreacion DATETIME NOT NULL,
    IdCuentaBancariaEmisora NVARCHAR(45) NOT NULL,
    IdCuentaBancariaRemitente NVARCHAR(45) NOT NULL,
    IdEstado INT NOT NULL,
    IdReglaTransaccion INT NOT NULL,
    FOREIGN KEY (IdCuentaBancariaEmisora) REFERENCES CuentasBancarias(IdCuentaBancaria),
    FOREIGN KEY (IdCuentaBancariaRemitente) REFERENCES CuentasBancarias(IdCuentaBancaria),
    FOREIGN KEY (IdEstado) REFERENCES Estado(IdEstado),
    FOREIGN KEY (IdReglaTransaccion) REFERENCES ReglaTransaccion(IdReglaTransaccion)
);

-- DetalleMaestro
CREATE TABLE DetalleMaestro (
    IdDetalleMaestro INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    MontoComision DECIMAL(18, 2) NOT NULL,
    MontoTransaccion DECIMAL(18, 2) NOT NULL,
    MontoTotal DECIMAL(18, 2) NOT NULL,
    IdTransaccion INT NOT NULL,
    IdComision INT NOT NULL,
    FOREIGN KEY (IdTransaccion) REFERENCES Transaccion(IdTransaccion),
    FOREIGN KEY (IdComision) REFERENCES ComisionesBancarias(IdComision)
);

-- TipoCambio
CREATE TABLE TipoCambio (
    IdTipoCambio INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    TipoCambio VARCHAR(45) NOT NULL UNIQUE,
    Porcentaje DECIMAL(18, 2) NOT NULL,
    IdTipoMoneda INT NOT NULL,
    FOREIGN KEY (IdTipoMoneda) REFERENCES TipoMoneda(IdTipoMoneda)
);



-- ***************************
-- Procedimientos Almacenados
-- ***************************

CREATE or ALTER PROCEDURE sp_transferirFondos
    @IdCuentaOrigen NVARCHAR(45),
    @IdCuentaDestino NVARCHAR(45),
    @Monto DECIMAL(18, 2)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SaldoOrigen DECIMAL(18, 2);
    DECLARE @IdEstado INT;
    DECLARE @IdReglaTransaccion INT;
    DECLARE @IdTransaccion INT;
    DECLARE @IdComision INT;
    DECLARE @PorcentajeComision DECIMAL(18, 2);
    DECLARE @MontoComision DECIMAL(18, 2);
    DECLARE @MontoTotal DECIMAL(18, 2);
    DECLARE @IdBancoOrigen INT;

    BEGIN TRY
        BEGIN TRAN;

        -- Validar existencia de cuentas
        IF NOT EXISTS (SELECT 1 FROM CuentasBancarias WHERE IdCuentaBancaria = @IdCuentaOrigen)
            THROW 51000, 'La cuenta origen no existe.', 1;

        IF NOT EXISTS (SELECT 1 FROM CuentasBancarias WHERE IdCuentaBancaria = @IdCuentaDestino)
            THROW 51001, 'La cuenta destino no existe.', 1;

        -- Obtener saldo de la cuenta origen
        SELECT @SaldoOrigen = Saldo, @IdBancoOrigen = IdBanco
        FROM CuentasBancarias
        WHERE IdCuentaBancaria = @IdCuentaOrigen;

        -- Validar saldo suficiente
        IF @SaldoOrigen < @Monto
            THROW 51002, 'Saldo insuficiente en la cuenta origen.', 1;

        -- Calcular comisión
        SELECT TOP 1 @IdComision = IdComision, @PorcentajeComision = Porcentaje
        FROM ComisionesBancarias
        WHERE IdBanco = @IdBancoOrigen;

        SET @MontoComision = (@Monto * @PorcentajeComision) / 100;
        SET @MontoTotal = @Monto + @MontoComision;

        -- Resta saldo de cuenta origen
        UPDATE CuentasBancarias
        SET Saldo = Saldo - @MontoTotal
        WHERE IdCuentaBancaria = @IdCuentaOrigen;

        -- Suma saldo a cuenta destino
        UPDATE CuentasBancarias
        SET Saldo = Saldo + @Monto
        WHERE IdCuentaBancaria = @IdCuentaDestino;

        -- Buscar regla aplicable para el monto
        SELECT TOP 1 @IdReglaTransaccion = IdReglaTransaccion
        FROM ReglaTransaccion
        WHERE IdBanco = @IdBancoOrigen
          AND @Monto BETWEEN RangoMinimo AND RangoMaximo;

        IF @IdReglaTransaccion IS NULL
            THROW 51003, 'No existe una regla de transacción válida para este monto.', 1;

        -- Insertar transacción
        INSERT INTO Transaccion (
            Detalle, FechaCreacion,
            IdCuentaBancariaEmisora, IdCuentaBancariaRemitente,
            IdEstado, IdReglaTransaccion
        )
        VALUES (
            CONCAT('Transferencia de ', @Monto, ' desde ', @IdCuentaOrigen, ' hacia ', @IdCuentaDestino),
            GETDATE(), @IdCuentaOrigen, @IdCuentaDestino,
            1,  -- Exitosa
            @IdReglaTransaccion
        );

        SET @IdTransaccion = SCOPE_IDENTITY();

        -- Insertar detalle maestro
        INSERT INTO DetalleMaestro (
            MontoComision, MontoTransaccion, MontoTotal,
            IdTransaccion, IdComision
        )
        VALUES (
            @MontoComision, @Monto, @MontoTotal,
            @IdTransaccion, @IdComision
        );

        COMMIT;
        PRINT 'Transferencia realizada exitosamente.';
    END TRY
    BEGIN CATCH
    ROLLBACK;

    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();

    -- Validar existencia de ambas cuentas
    IF EXISTS (SELECT 1 FROM CuentasBancarias WHERE IdCuentaBancaria = @IdCuentaOrigen)
       AND EXISTS (SELECT 1 FROM CuentasBancarias WHERE IdCuentaBancaria = @IdCuentaDestino)
    BEGIN
        -- Insertar transacción fallida solo si ambas cuentas existen
        INSERT INTO Transaccion (
            Detalle, FechaCreacion,
            IdCuentaBancariaEmisora, IdCuentaBancariaRemitente,
            IdEstado, IdReglaTransaccion
        )
        VALUES (
            CONCAT('Error: ', @ErrorMessage),
            GETDATE(), @IdCuentaOrigen, @IdCuentaDestino,
            2,  -- Estado Fallida
            ISNULL(@IdReglaTransaccion, 1)  -- Valor por defecto si no existe
        );
    END

    PRINT 'Error en la transferencia: ' + @ErrorMessage;
END CATCH
END;
GO

-- Vista de transacciones:
CREATE OR ALTER VIEW vw_TransaccionesDetalle AS
SELECT 
    t.IdTransaccion,
    t.FechaCreacion,
    t.Detalle AS Descripcion,
    ce.Nombre + ' ' + ce.Apellido AS Emisor,
    cr.Nombre + ' ' + cr.Apellido AS Receptor,
    e.Estado,
    dm.MontoTransaccion,
    dm.MontoComision,
    dm.MontoTotal,
    tm.Descripcion AS Moneda
FROM Transaccion t
INNER JOIN CuentasBancarias cb1 ON t.IdCuentaBancariaEmisora = cb1.IdCuentaBancaria
INNER JOIN CuentasBancarias cb2 ON t.IdCuentaBancariaRemitente = cb2.IdCuentaBancaria
INNER JOIN Clientes ce ON cb1.Cedula = ce.Cedula
INNER JOIN Clientes cr ON cb2.Cedula = cr.Cedula
INNER JOIN Estado e ON t.IdEstado = e.IdEstado
INNER JOIN DetalleMaestro dm ON dm.IdTransaccion = t.IdTransaccion
INNER JOIN TipoMoneda tm ON cb1.IdTipoMoneda = tm.IdTipoMoneda;
GO

