CREATE DATABASE dia01_gestion_avanzada_de_usuarios_y_roles;
USE dia01_gestion_avanzada_de_usuarios_y_roles;
GO

IF OBJECT_ID('Roles', 'U') IS NOT NULL
    DROP TABLE Roles;
GO

CREATE TABLE Roles (
    idRol INT PRIMARY KEY,
    NombreRol VARCHAR(45) NOT NULL,
    DescripcionRol VARCHAR(145) NOT NULL,
    CONSTRAINT NombreRol_UNIQUE UNIQUE (NombreRol)
);
GO

IF OBJECT_ID('Estados', 'U') IS NOT NULL
    DROP TABLE Estados;
GO

CREATE TABLE Estados (
    idEstado INT PRIMARY KEY,
    DescripcionEstado VARCHAR(45) NOT NULL,
    CONSTRAINT Estadoscol_UNIQUE UNIQUE (DescripcionEstado)
);
GO

IF OBJECT_ID('Empresas', 'U') IS NOT NULL
    DROP TABLE Empresas;
GO

CREATE TABLE Empresas (
    idEmpresa INT PRIMARY KEY,
    NombreEmpresa VARCHAR(45) NOT NULL,
    idEstado INT NOT NULL,
    CONSTRAINT idEmpresa_UNIQUE UNIQUE (idEmpresa),
    CONSTRAINT Empresascol_UNIQUE UNIQUE (NombreEmpresa),
    FOREIGN KEY (idEstado) REFERENCES Estados(idEstado)
);
GO

IF OBJECT_ID('Usuarios', 'U') IS NOT NULL
    DROP TABLE Usuarios;
GO

CREATE TABLE Usuarios (
    idUsuario INT PRIMARY KEY,
    NombreUsuario VARCHAR(45) NOT NULL,
    idEstado INT NOT NULL,
    Empresas_idEmpresa INT NOT NULL,
    CONSTRAINT NombreUsuario_UNIQUE UNIQUE (NombreUsuario),
    CONSTRAINT UsuarioId_UNIQUE UNIQUE (idUsuario),
    FOREIGN KEY (idEstado) REFERENCES Estados(idEstado),
    FOREIGN KEY (Empresas_idEmpresa) REFERENCES Empresas(idEmpresa)
);
GO

IF OBJECT_ID('Permisos', 'U') IS NOT NULL
    DROP TABLE Permisos;
GO

CREATE TABLE Permisos (
    idPermiso INT PRIMARY KEY,
    NombrePermiso VARCHAR(45) NOT NULL,
    DetallePermiso VARCHAR(145) NOT NULL,
    CONSTRAINT DetallePermiso_UNIQUE UNIQUE (NombrePermiso),
    CONSTRAINT idPermiso_UNIQUE UNIQUE (idPermiso)
);
GO

IF OBJECT_ID('Permisos_has_Roles', 'U') IS NOT NULL
    DROP TABLE Permisos_has_Roles;
GO

CREATE TABLE Permisos_has_Roles (
    Permisos_idPermiso INT NOT NULL,
    Roles_idRol INT NOT NULL,
    PRIMARY KEY (Permisos_idPermiso, Roles_idRol),
    FOREIGN KEY (Permisos_idPermiso) REFERENCES Permisos(idPermiso),
    FOREIGN KEY (Roles_idRol) REFERENCES Roles(idRol)
);
GO

IF OBJECT_ID('UsuariosRoles', 'U') IS NOT NULL
    DROP TABLE UsuariosRoles;
GO

CREATE TABLE UsuariosRoles (
    idUsuario INT NOT NULL,
    idRol INT NOT NULL,
    FechaAsignacion DATETIME NOT NULL,
    PRIMARY KEY (idUsuario, idRol),
    FOREIGN KEY (idUsuario) REFERENCES Usuarios(idUsuario),
    FOREIGN KEY (idRol) REFERENCES Roles(idRol)
);
GO

IF OBJECT_ID('Operaciones', 'U') IS NOT NULL
    DROP TABLE Operaciones;
GO

CREATE TABLE Operaciones (
    idOperacion INT PRIMARY KEY,
    Operacion VARCHAR(20) NOT NULL,
    CONSTRAINT idOperaciones_UNIQUE UNIQUE (idOperacion),
    CONSTRAINT Operacion_UNIQUE UNIQUE (Operacion)
);
GO

IF OBJECT_ID('AuditoriasUsuarioRol', 'U') IS NOT NULL
    DROP TABLE AuditoriasUsuarioRol;
GO

CREATE TABLE AuditoriasUsuarioRol (
    idAuditoria INT PRIMARY KEY,
    idUsuario INT NOT NULL,
    idRol INT NOT NULL,
    Fecha DATETIME NOT NULL,
    idOperacion INT NOT NULL,
    UNIQUE (idAuditoria),
    FOREIGN KEY (idUsuario, idRol) REFERENCES UsuariosRoles(idUsuario, idRol),
    FOREIGN KEY (idOperacion) REFERENCES Operaciones(idOperacion)
);
GO


-- **********************************
-- Crear secuencia para idAuditoria
-- **********************************
CREATE SEQUENCE seq_idAuditoria
    START WITH 1
    INCREMENT BY 1;
GO


-- ****************************************
-- EJECUCION DE PROCEDIMIENTOS ALMACENADOS
-- *************************************


CREATE PROCEDURE sp_AsignarPermisoARol
    @idRol INT,
    @idPermiso INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar existencia del rol
    IF NOT EXISTS (SELECT 1 FROM Roles WHERE idRol = @idRol)
    BEGIN
        RAISERROR('El rol no existe.', 16, 1);
        RETURN;
    END

    -- Validar existencia del permiso
    IF NOT EXISTS (SELECT 1 FROM Permisos WHERE idPermiso = @idPermiso)
    BEGIN
        RAISERROR('El permiso no existe.', 16, 1);
        RETURN;
    END

    -- Validar que no esté ya asignado
    IF EXISTS (SELECT 1 FROM Permisos_has_Roles WHERE Roles_idRol = @idRol AND Permisos_idPermiso = @idPermiso)
    BEGIN
        RAISERROR('El permiso ya está asignado al rol.', 16, 1);
        RETURN;
    END

    -- Asignar permiso al rol
    INSERT INTO Permisos_has_Roles (Permisos_idPermiso, Roles_idRol)
    VALUES (@idPermiso, @idRol);
END;
GO


CREATE PROCEDURE sp_RevocarPermisoDeRol
    @idRol INT,
    @idPermiso INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar que esté asignado
    IF NOT EXISTS (SELECT 1 FROM Permisos_has_Roles WHERE Roles_idRol = @idRol AND Permisos_idPermiso = @idPermiso)
    BEGIN
        RAISERROR('El permiso no está asignado al rol.', 16, 1);
        RETURN;
    END

    -- Revocar
    DELETE FROM Permisos_has_Roles
    WHERE Permisos_idPermiso = @idPermiso AND Roles_idRol = @idRol;
END;
GO


CREATE PROCEDURE sp_AsignarRolAUsuario
    @idUsuario INT,
    @idRol INT,
    @idOperacion INT = 1  -- 1: Asignación
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar existencia del usuario
    IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE idUsuario = @idUsuario)
    BEGIN
        RAISERROR('El usuario no existe.', 16, 1);
        RETURN;
    END

    -- Validar existencia del rol
    IF NOT EXISTS (SELECT 1 FROM Roles WHERE idRol = @idRol)
    BEGIN
        RAISERROR('El rol no existe.', 16, 1);
        RETURN;
    END

    -- Validar que no esté asignado ya
    IF EXISTS (SELECT 1 FROM UsuariosRoles WHERE idUsuario = @idUsuario AND idRol = @idRol)
    BEGIN
        RAISERROR('El rol ya está asignado al usuario.', 16, 1);
        RETURN;
    END

    -- Asignar rol
    INSERT INTO UsuariosRoles (idUsuario, idRol, FechaAsignacion)
    VALUES (@idUsuario, @idRol, GETDATE());

    -- Insertar en auditoría
    INSERT INTO AuditoriasUsuarioRol (idAuditoria, idUsuario, idRol, Fecha, idOperacion)
    VALUES (
        NEXT VALUE FOR seq_idAuditoria,
        @idUsuario,
        @idRol,
        GETDATE(),
        @idOperacion
    );
END;
GO



CREATE PROCEDURE sp_RevocarRolAUsuario
    @idUsuario INT,
    @idRol INT,
    @idOperacion INT = 2  -- 2: Revocación
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar asignación
    IF NOT EXISTS (SELECT 1 FROM UsuariosRoles WHERE idUsuario = @idUsuario AND idRol = @idRol)
    BEGIN
        RAISERROR('El rol no está asignado al usuario.', 16, 1);
        RETURN;
    END

    -- Eliminar asignación
    DELETE FROM UsuariosRoles
    WHERE idUsuario = @idUsuario AND idRol = @idRol;

    -- Insertar en auditoría
    INSERT INTO AuditoriasUsuarioRol (idAuditoria, idUsuario, idRol, Fecha, idOperacion)
    VALUES (
        NEXT VALUE FOR seq_idAuditoria,
        @idUsuario,
        @idRol,
        GETDATE(),
        @idOperacion
    );
END;
GO
