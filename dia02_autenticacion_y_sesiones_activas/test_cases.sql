-- Inserts

-- Insertar Estados
INSERT INTO Estados (Estado, Descripcion) VALUES
('Activo', 'Entidad activa y habilitada'),
('Inactivo', 'Entidad inactiva'),
('Bloqueado', 'Entidad bloqueada por intentos fallidos u otras razones');


-- Insertar Empresas
INSERT INTO Empresas (Nombre, Descripcion) VALUES
('OpenTech', 'Empresa de tecnología'),
('SafeCorp', 'Empresa de seguridad digital'),
('LogiNet', 'Red de logística y datos');


-- Insertar Acciones
INSERT INTO Acciones (Accion, Descripcion) VALUES
('LOGIN_EXITOSO', 'Inicio de sesión correcto'),
('LOGIN_FALLIDO', 'Intento de inicio de sesión fallido'),
('LOGOUT', 'Cierre de sesión'),
('CREAR_USUARIO', 'Creación de un nuevo usuario'),
('CAMBIO_ESTADO', 'Cambio de estado del usuario'),
('BLOQUEO_IP', 'DireccionIP bloqueada por intentos fallidos');


-- Insertar Usuarios
INSERT INTO Usuarios (Usuario, ContrasenaHash, IdEmpresas, IdEstado) VALUES
('admin1', HASHBYTES('SHA2_256', 'admin123'), 1, 1),
('jose.mora', HASHBYTES('SHA2_256', 'secreto123'), 2, 1),
('cristina.v', HASHBYTES('SHA2_256', 'clave456'), 3, 1);
('usuario.sistema', HASHBYTES('SHA2_256', 'sistema'), 3, 1);

-- Insertar IPs
INSERT INTO IPs (DireccionIP, IdUsuario, IdEstado) VALUES
('192.168.1.10', 1, 1),
('192.168.1.15', 2, 1),
('10.0.0.5', 3, 1);


Select * from IPs
Select * from Usuarios
Select * from Acciones
Select * from Empresas
Select * from Estados
Select * from auditorias
Select * from sesiones
Select * from SesionesFallidas