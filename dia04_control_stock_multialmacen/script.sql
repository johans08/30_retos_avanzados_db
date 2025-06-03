-- Crear la base de datos
CREATE DATABASE dia04_control_stock_multialmacen;
GO

USE dia04_control_stock_multialmacen;
GO

-- Tabla: Almacenes
CREATE TABLE Almacenes (
    IdAlmacen INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(100) NOT NULL,
    Ubicacion NVARCHAR(150) NOT NULL
);

-- Tabla: Productos
CREATE TABLE Productos (
    IdProducto INT IDENTITY(1,1) PRIMARY KEY,
    CodigoSKU NVARCHAR(50) NOT NULL UNIQUE,
    Nombre NVARCHAR(100) NOT NULL,
    Descripcion NVARCHAR(255)
);

-- Tabla: Estados
CREATE TABLE Estados (
    IdEstado INT IDENTITY(1,1) PRIMARY KEY,
    Estado NVARCHAR(50) NOT NULL
);

-- Tabla: Inventario
CREATE TABLE Inventarios (
    IdInventario INT IDENTITY(1,1) PRIMARY KEY,
    IdAlmacen INT NOT NULL,
    IdProducto INT NOT NULL,
    Cantidad INT NOT NULL,
    FechaActualizacion DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (IdAlmacen) REFERENCES Almacenes(IdAlmacen),
    FOREIGN KEY (IdProducto) REFERENCES Productos(IdProducto)
);

-- Tabla: Movimientos
CREATE TABLE Movimientos (
    IdMovimiento INT IDENTITY(1,1) PRIMARY KEY,
    IdProducto INT NOT NULL,
    AlmacenOrigen INT,
    AlmacenDestino INT,
    Cantidad INT NOT NULL,
    FechaMovimiento DATETIME NOT NULL DEFAULT GETDATE(),
    IdEstado INT NOT NULL,
    FOREIGN KEY (IdProducto) REFERENCES Productos(IdProducto),
    FOREIGN KEY (AlmacenOrigen) REFERENCES Almacenes(IdAlmacen),
    FOREIGN KEY (AlmacenDestino) REFERENCES Almacenes(IdAlmacen),
    FOREIGN KEY (IdEstado) REFERENCES Estados(IdEstado)
);



-- Procedimiento Almacenado

-- Registrar Movimiento y actualizar stock
CREATE OR ALTER PROCEDURE RegistrarMovimiento
    @IdProducto INT,
    @Cantidad INT,
    @IdEstado INT,
    @AlmacenOrigen INT = NULL,
    @AlmacenDestino INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF @IdEstado = 1 -- Ingreso
        BEGIN
            MERGE Inventarios AS target
            USING (SELECT @AlmacenDestino AS IdAlmacen, @IdProducto AS IdProducto) AS source
            ON target.IdAlmacen = source.IdAlmacen AND target.IdProducto = source.IdProducto
            WHEN MATCHED THEN
                UPDATE SET Cantidad = Cantidad + @Cantidad, FechaActualizacion = GETDATE()
            WHEN NOT MATCHED THEN
                INSERT (IdAlmacen, IdProducto, Cantidad) VALUES (@AlmacenDestino, @IdProducto, @Cantidad);

            INSERT INTO Movimientos (IdProducto, AlmacenDestino, Cantidad, IdEstado)
            VALUES (@IdProducto, @AlmacenDestino, @Cantidad, @IdEstado);

            COMMIT;
            SELECT 'Movimiento de ingreso registrado exitosamente.' AS Mensaje;
        END

        ELSE IF @IdEstado = 2 -- Salida
        BEGIN
            DECLARE @StockActual INT;
            SELECT @StockActual = Cantidad FROM Inventarios WHERE IdAlmacen = @AlmacenOrigen AND IdProducto = @IdProducto;

            IF @StockActual IS NULL
            BEGIN
                ROLLBACK;
                SELECT 'No existe stock para este producto en el almacén origen.' AS Mensaje;
                RETURN;
            END

            IF @StockActual < @Cantidad
            BEGIN
                ROLLBACK;
                SELECT 'Stock insuficiente para realizar la salida.' AS Mensaje;
                RETURN;
            END

            UPDATE Inventarios
            SET Cantidad = Cantidad - @Cantidad, FechaActualizacion = GETDATE()
            WHERE IdAlmacen = @AlmacenOrigen AND IdProducto = @IdProducto;

            INSERT INTO Movimientos (IdProducto, AlmacenOrigen, Cantidad, IdEstado)
            VALUES (@IdProducto, @AlmacenOrigen, @Cantidad, @IdEstado);

            COMMIT;
            SELECT 'Movimiento de salida registrado exitosamente.' AS Mensaje;
        END

        ELSE IF @IdEstado = 3 -- Transferencia
        BEGIN
            DECLARE @StockTransf INT;
            SELECT @StockTransf = Cantidad FROM Inventarios WHERE IdAlmacen = @AlmacenOrigen AND IdProducto = @IdProducto;

            IF @StockTransf IS NULL
            BEGIN
                ROLLBACK;
                SELECT 'No existe stock para este producto en el almacén origen.' AS Mensaje;
                RETURN;
            END

            IF @StockTransf < @Cantidad
            BEGIN
                ROLLBACK;
                SELECT 'Stock insuficiente para realizar la transferencia.' AS Mensaje;
                RETURN;
            END

            -- Descontar del origen
            UPDATE Inventarios
            SET Cantidad = Cantidad - @Cantidad, FechaActualizacion = GETDATE()
            WHERE IdAlmacen = @AlmacenOrigen AND IdProducto = @IdProducto;

            -- Agregar al destino
            MERGE Inventarios AS target
            USING (SELECT @AlmacenDestino AS IdAlmacen, @IdProducto AS IdProducto) AS source
            ON target.IdAlmacen = source.IdAlmacen AND target.IdProducto = source.IdProducto
            WHEN MATCHED THEN
                UPDATE SET Cantidad = Cantidad + @Cantidad, FechaActualizacion = GETDATE()
            WHEN NOT MATCHED THEN
                INSERT (IdAlmacen, IdProducto, Cantidad) VALUES (@AlmacenDestino, @IdProducto, @Cantidad);

            INSERT INTO Movimientos (IdProducto, AlmacenOrigen, AlmacenDestino, Cantidad, IdEstado)
            VALUES (@IdProducto, @AlmacenOrigen, @AlmacenDestino, @Cantidad, @IdEstado);

            COMMIT;
            SELECT 'Movimiento de transferencia registrado exitosamente.' AS Mensaje;
        END
        ELSE
        BEGIN
            ROLLBACK;
            SELECT 'Estado de movimiento no válido. Verifique el parámetro @IdEstado.' AS Mensaje;
        END
    END TRY
    BEGIN CATCH
        ROLLBACK;
        SELECT 
            'Error inesperado en la operación.' AS Mensaje,
            ERROR_MESSAGE() AS Detalle;
    END CATCH
END;




-- Vistas


-- Vista de stock actual consolidado por almacén y producto
CREATE OR ALTER VIEW Vista_StockActual AS
SELECT
    a.Nombre AS Almacen,
    p.Nombre AS Producto,
    i.Cantidad,
    i.FechaActualizacion
FROM Inventarios i
INNER JOIN Almacenes a ON i.IdAlmacen = a.IdAlmacen
INNER JOIN Productos p ON i.IdProducto = p.IdProducto;


-- Vista de movimientos detallados
CREATE OR ALTER VIEW Vista_MovimientosDetalle AS
SELECT
    m.IdMovimiento,
    p.Nombre AS Producto,
    e.Estado,
    ao.Nombre AS AlmacenOrigen,
    ad.Nombre AS AlmacenDestino,
    m.Cantidad,
    m.FechaMovimiento
FROM Movimientos m
INNER JOIN Productos p ON m.IdProducto = p.IdProducto
INNER JOIN Estados e ON m.IdEstado = e.IdEstado
LEFT JOIN Almacenes ao ON m.AlmacenOrigen = ao.IdAlmacen
LEFT JOIN Almacenes ad ON m.AlmacenDestino = ad.IdAlmacen;
