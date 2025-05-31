-- ***************************************************
-- INSERTS BASICOS PARA EL FUNCIONAMIENTO
-- ***************************************************


INSERT INTO Estados (idEstado, DescripcionEstado) VALUES
(1, 'Activo'),
(2, 'Inactivo');


INSERT INTO Empresas (idEmpresa, NombreEmpresa, idEstado) VALUES
(1, 'TechCorp', 1),
(2, 'BioLabs', 2);


INSERT INTO Roles (idRol, NombreRol, DescripcionRol) VALUES
(1, 'Administrador', 'Control total del sistema'),
(2, 'Editor', 'Puede modificar datos'),
(3, 'Lector', 'Solo lectura');


INSERT INTO Permisos (idPermiso, NombrePermiso, DetallePermiso) VALUES
(1, 'Crear', 'Permite crear registros'),
(2, 'Editar', 'Permite editar registros'),
(3, 'Eliminar', 'Permite eliminar registros'),
(4, 'Ver', 'Permite visualizar registros');


INSERT INTO Usuarios (idUsuario, NombreUsuario, idEstado, Empresas_idEmpresa) VALUES
(1, 'juan.gomez', 1, 1),
(2, 'ana.lopez', 1, 2),
(3, 'carlos.mora', 2, 1);


INSERT INTO Operaciones (idOperacion, Operacion) VALUES
(1, 'ASIGNAR'),
(2, 'REVOCAR');



-- ****************************************
-- EJECUCION DE PROCEDIMIENTOS ALMACENADOS
-- ****************************************


-- ***********************
-- ASIGNAR PERMISOS A ROL
-- ***********************


-- Asignar permisos
EXEC sp_AsignarPermisoARol @idRol = 1, @idPermiso = 1;
EXEC sp_AsignarPermisoARol @idRol = 1, @idPermiso = 2;

-- Duplicado (debe fallar)
EXEC sp_AsignarPermisoARol @idRol = 1, @idPermiso = 2;




-- ***********************
-- REVOCAR PERMISOS A ROL
-- ***********************


-- Revocar correctamente
EXEC sp_RevocarPermisoDeRol @idRol = 1, @idPermiso = 2;

-- Revocar inexistente (debe fallar)
EXEC sp_RevocarPermisoDeRol @idRol = 1, @idPermiso = 3;




-- ***********************
-- Asignar Rol al Usuario
-- ***********************


-- Asignar Rol 1 a Usuario 1
EXEC sp_AsignarRolAUsuario @idUsuario = 1, @idRol = 1;

-- Intentar asignar el mismo rol (debe dar error)
EXEC sp_AsignarRolAUsuario @idUsuario = 1, @idRol = 1;

-- Asignar Rol 2 a Usuario 2
EXEC sp_AsignarRolAUsuario @idUsuario = 2, @idRol = 2;

-- Asignar Rol a usuario que no exista
EXEC sp_AsignarRolAUsuario @idUsuario = 322, @idRol = 2;

-- Asignar Rol que no exista a usuario
EXEC sp_AsignarRolAUsuario @idUsuario = 2, @idRol = 122;


-- ***********************
-- Revocar Rol al Usuario
-- ***********************


-- Revocar rol correctamente
EXEC sp_RevocarRolAUsuario @idUsuario = 2, @idRol = 2;

-- Intentar revocar un rol que no existe (debe dar error)
EXEC sp_RevocarRolAUsuario @idUsuario = 2, @idRol = 2;




-- ***********************
-- CONSULTAS DE VALIDACION
-- ***********************

-- Ver permisos asignados a cada rol:
SELECT r.NombreRol, p.NombrePermiso
FROM Permisos_has_Roles pr
JOIN Roles r ON pr.Roles_idRol = r.idRol
JOIN Permisos p ON pr.Permisos_idPermiso = p.idPermiso
ORDER BY r.NombreRol;

-- Ver roles asignados a cada usuario:
SELECT u.NombreUsuario, r.NombreRol
FROM UsuariosRoles ur
JOIN Usuarios u ON ur.idUsuario = u.idUsuario
JOIN Roles r ON ur.idRol = r.idRol
ORDER BY u.NombreUsuario;

-- Ver auditoría de roles:
SELECT * FROM AuditoriasUsuarioRol;
