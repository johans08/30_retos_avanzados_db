-- Crear la base de datos
CREATE DATABASE dia02_autenticacion_y_sesiones_activas;
GO

USE dia02_autenticacion_y_sesiones_activas;
GO

-- Tabla: Empresas
CREATE TABLE Empresas (
    IdEmpresa INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(45) NOT NULL UNIQUE,
    Descripcion NVARCHAR(100) NOT NULL
);

-- Tabla: Estados (compartida)
CREATE TABLE Estados (
    IdEstado INT IDENTITY(1,1) PRIMARY KEY,
    Estado NVARCHAR(45) NOT NULL UNIQUE,
    Descripcion NVARCHAR(100) NOT NULL
);

-- Tabla: Usuarios
CREATE TABLE Usuarios (
    IdUsuario INT IDENTITY(1,1) PRIMARY KEY,
    Usuario NVARCHAR(25) NOT NULL UNIQUE,
    ContrasenaHash VARBINARY(256) NOT NULL,
    IdEmpresas INT NOT NULL,
    IdEstado INT NOT NULL,
    FOREIGN KEY (IdEmpresas) REFERENCES Empresas(IdEmpresa),
    FOREIGN KEY (IdEstado) REFERENCES Estados(IdEstado)
);


-- Tabla: Acciones
CREATE TABLE Acciones (
    IdAccion INT IDENTITY(1,1) PRIMARY KEY,
    Accion NVARCHAR(45) NOT NULL,
    Descripcion NVARCHAR(100) NOT NULL
);

-- Tabla: Sesiones
CREATE TABLE Sesiones (
    TokenSesion UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    InicioSesion DATETIME2 NOT NULL,
    FinSesion DATETIME2 NULL,
    IdUsuario INT NOT NULL,
    IdEstado INT NOT NULL,
    FOREIGN KEY (IdUsuario) REFERENCES Usuarios(IdUsuario),
    FOREIGN KEY (IdEstado) REFERENCES Estados(IdEstado)
);

-- Tabla: Auditorias
CREATE TABLE Auditorias (
    IdAuditoria INT IDENTITY(1,1) PRIMARY KEY,
    HoraCreacion DATETIME2 NOT NULL DEFAULT GETDATE(),
    IdAccion INT NOT NULL,
    TokenSesion UNIQUEIDENTIFIER NOT NULL,
    FOREIGN KEY (IdAccion) REFERENCES Acciones(IdAccion),
    FOREIGN KEY (TokenSesion) REFERENCES Sesiones(TokenSesion)
);

-- Tabla: IPs
CREATE TABLE IPs (
    DireccionIP NVARCHAR(45) PRIMARY KEY,
    IdUsuario INT NOT NULL,
    IdEstado INT NOT NULL,
    FOREIGN KEY (IdUsuario) REFERENCES Usuarios(IdUsuario),
    FOREIGN KEY (IdEstado) REFERENCES Estados(IdEstado)
);

-- Tabla: SesionesFallidas
CREATE TABLE SesionesFallidas (
    IdSesionFallida INT IDENTITY(1,1) PRIMARY KEY,
    HoraFallo DATETIME2 NOT NULL DEFAULT GETDATE(),
    Motivo NVARCHAR(100) NOT NULL,
    IdUsuario INT NOT NULL,
    DireccionIP NVARCHAR(45) NOT NULL,
    FOREIGN KEY (IdUsuario) REFERENCES Usuarios(IdUsuario),
    FOREIGN KEY (DireccionIP) REFERENCES IPs(DireccionIP)
);



-- ***************************
-- Procediminetos almacenados
-- ***************************

-- Iniciar sesion
CREATE OR ALTER PROCEDURE SP_InicioSesion
    @Usuario NVARCHAR(25),
    @Contrasena NVARCHAR(255),
    @Ip VARCHAR(45)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
        @IdUsuario INT,
        @HashIngresado VARBINARY(256),
        @HashAlmacenado VARBINARY(256),
        @EstadoUsuario INT,
        @TokenSesion CHAR(36) = CONVERT(CHAR(36), NEWID());

    BEGIN TRY
        -- Asegurar que la IP esté registrada en la tabla IPs
        IF NOT EXISTS (SELECT 1 FROM IPs WHERE DireccionIP = @Ip)
        BEGIN
            INSERT INTO IPs (DireccionIP, IdUsuario, IdEstado)
            VALUES (@Ip, 4, 2); -- 4 = usuario del sistema, 2 = estado sospechoso
        END

        -- Convertir contraseña ingresada
        SET @HashIngresado = HASHBYTES('SHA2_256', CONVERT(VARCHAR(255), @Contrasena));

        -- Buscar usuario
        SELECT 
            @IdUsuario = U.IdUsuario,
            @HashAlmacenado = U.ContrasenaHash,
            @EstadoUsuario = U.IdEstado
        FROM Usuarios U
        WHERE U.Usuario = @Usuario;

        -- Validar usuario
        IF @IdUsuario IS NULL
        BEGIN
            INSERT INTO SesionesFallidas (HoraFallo, Motivo, IdUsuario, DireccionIP)
            VALUES (GETDATE(), 'Usuario no encontrado', 0, @Ip);

            PRINT 'Error: Usuario no encontrado.';
            RETURN;
        END

        -- Validar contraseña
        IF @HashAlmacenado = @HashIngresado
        BEGIN
            -- Validar estado del usuario
            IF @EstadoUsuario <> 1
            BEGIN
                INSERT INTO SesionesFallidas (HoraFallo, Motivo, IdUsuario, DireccionIP)
                VALUES (GETDATE(), 'Usuario inactivo o bloqueado', @IdUsuario, @Ip);

                PRINT 'Error: Usuario inactivo o bloqueado.';
                RETURN;
            END

            -- Validar sesión activa existente
            IF EXISTS (
                SELECT 1 
                FROM Sesiones 
                WHERE IdUsuario = @IdUsuario AND IdEstado = 1
            )
            BEGIN
                INSERT INTO SesionesFallidas (HoraFallo, Motivo, IdUsuario, DireccionIP)
                VALUES (GETDATE(), 'Sesion activa existente', @IdUsuario, @Ip);

                PRINT 'Error: Sesión activa existente.';
                RETURN;
            END

            -- Crear nueva sesión
            INSERT INTO Sesiones (TokenSesion, InicioSesion, FinSesion, IdUsuario, IdEstado)
            VALUES (@TokenSesion, GETDATE(), NULL, @IdUsuario, 1);

            -- Registrar auditoría de inicio de sesión
            INSERT INTO Auditorias (HoraCreacion, IdAccion, TokenSesion)
            VALUES (GETDATE(), 1, @TokenSesion);

            PRINT 'Sesión iniciada correctamente. Token: ' + @TokenSesion;
        END
        ELSE
        BEGIN
            -- Contraseña incorrecta
            INSERT INTO SesionesFallidas (HoraFallo, Motivo, IdUsuario, DireccionIP)
            VALUES (GETDATE(), 'Contraseña incorrecta', @IdUsuario, @Ip);

            PRINT 'Error: Contraseña incorrecta.';
        END
    END TRY
    BEGIN CATCH
        PRINT 'Error inesperado: ' + ERROR_MESSAGE();
    END CATCH
END;


-- Cerrar sesion manual
CREATE OR ALTER PROCEDURE SP_CerrarSesionManual
    @TokenSesion CHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (
            SELECT 1 FROM Sesiones 
            WHERE TokenSesion = @TokenSesion AND IdEstado = 1
        )
        BEGIN
            PRINT 'Error: La sesión no existe o ya está cerrada.';
            RETURN;
        END

        UPDATE Sesiones
        SET 
            FinSesion = GETDATE(),
            IdEstado = 2  -- 2 = Cerrada manualmente
        WHERE TokenSesion = @TokenSesion;

        -- Registrar auditoría
        INSERT INTO Auditorias (HoraCreacion, IdAccion, TokenSesion)
        VALUES (GETDATE(), 2, @TokenSesion); -- 2 = Cierre de sesión

        PRINT 'Sesión cerrada correctamente.';
    END TRY
    BEGIN CATCH
        PRINT 'Error inesperado: ' + ERROR_MESSAGE();
    END CATCH
END;


-- Cerrar sesion automatica
CREATE OR ALTER PROCEDURE SP_CerrarSesionesInactivas
    @MinutosInactividad INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @Limite DATETIME = DATEADD(MINUTE, -@MinutosInactividad, GETDATE());

        -- Variable tabla para capturar tokens actualizados
        DECLARE @Tokens TABLE (TokenSesion CHAR(36));

        -- Actualizar sesiones activas y capturar tokens afectados
        UPDATE Sesiones
        SET 
            FinSesion = GETDATE(),
            IdEstado = 2  -- 3 = Cerrada automáticamente por inactividad
        OUTPUT inserted.TokenSesion INTO @Tokens
        WHERE IdEstado = 1 AND InicioSesion <= @Limite;

        -- Registrar en auditoría para cada token actualizado
        INSERT INTO Auditorias (HoraCreacion, IdAccion, TokenSesion)
        SELECT 
            GETDATE(),
            3, -- 3 = Cierre automático
            TokenSesion
        FROM @Tokens;

        PRINT 'Sesiones inactivas cerradas correctamente.';
    END TRY
    BEGIN CATCH
        PRINT 'Error inesperado: ' + ERROR_MESSAGE();
    END CATCH
END;





-- Caso 1: Usuario correcto y contraseña correcta (login exitoso)
EXEC SP_InicioSesion @Usuario = 'admin1', @Contrasena = 'admin123', @Ip = '192.168.1.10';

-- Caso 2: Usuario correcto pero contraseña incorrecta
EXEC SP_InicioSesion @Usuario = 'admin1', @Contrasena = 'wrongpassword', @Ip = '192.168.1.101';

-- Caso 3: Usuario no existe
EXEC SP_InicioSesion @Usuario = 'usuarioNoExiste', @Contrasena = 'algunaClave', @Ip = '192.168.1.102';

-- Caso 4: Usuario existe pero está inactivo o bloqueado (asegúrate de tener un usuario con IdEstado distinto a 1)
EXEC SP_InicioSesion @Usuario = 'usuarioInactivo', @Contrasena = 'claveCorrecta', @Ip = '192.168.1.103';

-- Caso 5: Intentar iniciar sesión cuando ya hay sesión activa para ese usuario (debes tener una sesión activa en la tabla Sesiones con IdEstado=1 para ese usuario)
EXEC SP_InicioSesion @Usuario = 'admin1', @Contrasena = 'admin123', @Ip = '192.168.1.104';

-- Caso 6: Cerrar sesiones por tiempo automatico
EXEC SP_CerrarSesionesInactivas @MinutosInactividad = 220;

-- Caso 7: Cerrar sesiones manual por boton
EXEC SP_CerrarSesionManual 'B17A9F39-81E5-481F-B143-87CC03DD4D40';