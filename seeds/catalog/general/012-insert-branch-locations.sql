-- ======================================================
-- SEED: general/012-insert-branch-locations.sql
-- ======================================================
-- Descripción: Llena la tabla territorio_catalog con TODOS los territorios
--              de Costa Rica según División del Territorio 2007
--              (Provincia, Cantón y Distrito)
-- Fuente: División del Territorio de Costa Rica Por: Provincia, Cantón y Distrito
--         Según: Código 2007
-- ======================================================

BEGIN;

-- Crear tabla de catálogo de territorios si no existe
CREATE TABLE IF NOT EXISTS general_schema.territorio_catalog (
    territorio_id SERIAL PRIMARY KEY,
    codigo VARCHAR(5) UNIQUE NOT NULL,  -- PPCDD (Provincia, Cantón, Distrito)
    provincia VARCHAR(1) NOT NULL,      -- 1-7
    canton VARCHAR(2) NOT NULL,         -- 01-XX
    distrito VARCHAR(2) NOT NULL,       -- 01-XX
    provincia_nombre VARCHAR(100) NOT NULL,
    canton_nombre VARCHAR(100) NOT NULL,
    distrito_nombre VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Crear índices para búsquedas rápidas
CREATE INDEX IF NOT EXISTS idx_territorio_codigo ON general_schema.territorio_catalog(codigo);
CREATE INDEX IF NOT EXISTS idx_territorio_provincia ON general_schema.territorio_catalog(provincia);
CREATE INDEX IF NOT EXISTS idx_territorio_canton ON general_schema.territorio_catalog(canton);

-- Insertar TODOS los territorios de Costa Rica
INSERT INTO general_schema.territorio_catalog (codigo, provincia, canton, distrito, provincia_nombre, canton_nombre, distrito_nombre)
VALUES
-- PROVINCIA 1: SAN JOSE
-- CANTON 101: SAN JOSE
('10101', '1', '01', '01', 'San José', 'San José', 'Carmen'),
('10102', '1', '01', '02', 'San José', 'San José', 'Merced'),
('10103', '1', '01', '03', 'San José', 'San José', 'Hospital'),
('10104', '1', '01', '04', 'San José', 'San José', 'Catedral'),
('10105', '1', '01', '05', 'San José', 'San José', 'Zapote'),
('10106', '1', '01', '06', 'San José', 'San José', 'San Francisco de Dos Ríos'),
('10107', '1', '01', '07', 'San José', 'San José', 'Uruca'),
('10108', '1', '01', '08', 'San José', 'San José', 'Mata Redonda'),
('10109', '1', '01', '09', 'San José', 'San José', 'Pavas'),
('10110', '1', '01', '10', 'San José', 'San José', 'Hatillo'),
('10111', '1', '01', '11', 'San José', 'San José', 'San Sebastián'),
-- CANTON 102: ESCAZU
('10201', '1', '02', '01', 'San José', 'Escazú', 'Escazú'),
('10202', '1', '02', '02', 'San José', 'Escazú', 'San Antonio'),
('10203', '1', '02', '03', 'San José', 'Escazú', 'San Rafael'),
-- CANTON 103: DESAMPARADOS
('10301', '1', '03', '01', 'San José', 'Desamparados', 'Desamparados'),
('10302', '1', '03', '02', 'San José', 'Desamparados', 'San Miguel'),
('10303', '1', '03', '03', 'San José', 'Desamparados', 'San Juan de Dios'),
('10304', '1', '03', '04', 'San José', 'Desamparados', 'San Rafael Arriba'),
('10305', '1', '03', '05', 'San José', 'Desamparados', 'San Antonio'),
('10306', '1', '03', '06', 'San José', 'Desamparados', 'Frailes'),
('10307', '1', '03', '07', 'San José', 'Desamparados', 'Patarrá'),
('10308', '1', '03', '08', 'San José', 'Desamparados', 'San Cristóbal'),
('10309', '1', '03', '09', 'San José', 'Desamparados', 'Rosario'),
('10310', '1', '03', '10', 'San José', 'Desamparados', 'Damas'),
('10311', '1', '03', '11', 'San José', 'Desamparados', 'San Rafael Abajo'),
('10312', '1', '03', '12', 'San José', 'Desamparados', 'Gravilias'),
('10313', '1', '03', '13', 'San José', 'Desamparados', 'Los Guido'),
-- CANTON 104: PURISCAL
('10401', '1', '04', '01', 'San José', 'Puriscal', 'Santiago'),
('10402', '1', '04', '02', 'San José', 'Puriscal', 'Mercedes Sur'),
('10403', '1', '04', '03', 'San José', 'Puriscal', 'Barbacoas'),
('10404', '1', '04', '04', 'San José', 'Puriscal', 'Grifo Alto'),
('10405', '1', '04', '05', 'San José', 'Puriscal', 'San Rafael'),
('10406', '1', '04', '06', 'San José', 'Puriscal', 'Candelaria'),
('10407', '1', '04', '07', 'San José', 'Puriscal', 'Desamparaditos'),
('10408', '1', '04', '08', 'San José', 'Puriscal', 'San Antonio'),
('10409', '1', '04', '09', 'San José', 'Puriscal', 'Chires'),
-- CANTON 105: TARRAZU
('10501', '1', '05', '01', 'San José', 'Tarrazú', 'San Marcos'),
('10502', '1', '05', '02', 'San José', 'Tarrazú', 'San Lorenzo'),
('10503', '1', '05', '03', 'San José', 'Tarrazú', 'San Carlos'),
-- CANTON 106: ASERRI
('10601', '1', '06', '01', 'San José', 'Aserrí', 'Aserrí'),
('10602', '1', '06', '02', 'San José', 'Aserrí', 'Tarbaca o Praga'),
('10603', '1', '06', '03', 'San José', 'Aserrí', 'Vuelta de Jorco'),
('10604', '1', '06', '04', 'San José', 'Aserrí', 'San Gabriel'),
('10605', '1', '06', '05', 'San José', 'Aserrí', 'La Legua'),
('10606', '1', '06', '06', 'San José', 'Aserrí', 'Monterrey'),
('10607', '1', '06', '07', 'San José', 'Aserrí', 'Salitrillos'),
-- CANTON 107: MORA
('10701', '1', '07', '01', 'San José', 'Mora', 'Colón'),
('10702', '1', '07', '02', 'San José', 'Mora', 'Guayabo'),
('10703', '1', '07', '03', 'San José', 'Mora', 'Tabarcia'),
('10704', '1', '07', '04', 'San José', 'Mora', 'Piedras Negras'),
('10705', '1', '07', '05', 'San José', 'Mora', 'Picagres'),
-- CANTON 108: GOICOECHEA
('10801', '1', '08', '01', 'San José', 'Goicoechea', 'Guadalupe'),
('10802', '1', '08', '02', 'San José', 'Goicoechea', 'San Francisco'),
('10803', '1', '08', '03', 'San José', 'Goicoechea', 'Calle Blancos'),
('10804', '1', '08', '04', 'San José', 'Goicoechea', 'Mata de Plátano'),
('10805', '1', '08', '05', 'San José', 'Goicoechea', 'Ipís'),
('10806', '1', '08', '06', 'San José', 'Goicoechea', 'Rancho Redondo'),
('10807', '1', '08', '07', 'San José', 'Goicoechea', 'Purral'),
-- CANTON 109: SANTA ANA
('10901', '1', '09', '01', 'San José', 'Santa Ana', 'Santa Ana'),
('10902', '1', '09', '02', 'San José', 'Santa Ana', 'Salitral'),
('10903', '1', '09', '03', 'San José', 'Santa Ana', 'Pozos o Concepción'),
('10904', '1', '09', '04', 'San José', 'Santa Ana', 'Uruca o San Joaquín'),
('10905', '1', '09', '05', 'San José', 'Santa Ana', 'Piedades'),
('10906', '1', '09', '06', 'San José', 'Santa Ana', 'Brasil'),
-- CANTON 110: ALAJUELITA
('11001', '1', '10', '01', 'San José', 'Alajuelita', 'Alajuelita'),
('11002', '1', '10', '02', 'San José', 'Alajuelita', 'San Josecito'),
('11003', '1', '10', '03', 'San José', 'Alajuelita', 'San Antonio'),
('11004', '1', '10', '04', 'San José', 'Alajuelita', 'Concepción'),
('11005', '1', '10', '05', 'San José', 'Alajuelita', 'San Felipe'),
-- CANTON 111: CORONADO
('11101', '1', '11', '01', 'San José', 'Coronado', 'San Isidro'),
('11102', '1', '11', '02', 'San José', 'Coronado', 'San Rafael'),
('11103', '1', '11', '03', 'San José', 'Coronado', 'Dulce Nombre o Jesús'),
('11104', '1', '11', '04', 'San José', 'Coronado', 'Patalillo'),
('11105', '1', '11', '05', 'San José', 'Coronado', 'Cascajal'),
-- CANTON 112: ACOSTA
('11201', '1', '12', '01', 'San José', 'Acosta', 'San Ignacio'),
('11202', '1', '12', '02', 'San José', 'Acosta', 'Guaitil'),
('11203', '1', '12', '03', 'San José', 'Acosta', 'Palmichal'),
('11204', '1', '12', '04', 'San José', 'Acosta', 'Cangrejal'),
('11205', '1', '12', '05', 'San José', 'Acosta', 'Sabanillas'),
-- CANTON 113: TIBAS
('11301', '1', '13', '01', 'San José', 'Tibás', 'San Juan'),
('11302', '1', '13', '02', 'San José', 'Tibás', 'Cinco Esquinas'),
('11303', '1', '13', '03', 'San José', 'Tibás', 'Anselmo Llorente'),
('11304', '1', '13', '04', 'San José', 'Tibás', 'León XIII'),
('11305', '1', '13', '05', 'San José', 'Tibás', 'Colima'),
-- CANTON 114: MORAVIA
('11401', '1', '14', '01', 'San José', 'Moravia', 'San Vicente'),
('11402', '1', '14', '02', 'San José', 'Moravia', 'San Jerónimo'),
('11403', '1', '14', '03', 'San José', 'Moravia', 'La Trinidad'),
-- CANTON 115: MONTES DE OCA
('11501', '1', '15', '01', 'San José', 'Montes de Oca', 'San Pedro'),
('11502', '1', '15', '02', 'San José', 'Montes de Oca', 'Sabanilla'),
('11503', '1', '15', '03', 'San José', 'Montes de Oca', 'Mercedes o Betania'),
('11504', '1', '15', '04', 'San José', 'Montes de Oca', 'San Rafael'),
-- CANTON 116: TURRUBARES
('11601', '1', '16', '01', 'San José', 'Turrubares', 'San Pablo'),
('11602', '1', '16', '02', 'San José', 'Turrubares', 'San Pedro'),
('11603', '1', '16', '03', 'San José', 'Turrubares', 'San Juan de Mata'),
('11604', '1', '16', '04', 'San José', 'Turrubares', 'San Luis'),
('11605', '1', '16', '05', 'San José', 'Turrubares', 'Carara'),
-- CANTON 117: DOTA
('11701', '1', '17', '01', 'San José', 'Dota', 'Santa María'),
('11702', '1', '17', '02', 'San José', 'Dota', 'Jardín'),
('11703', '1', '17', '03', 'San José', 'Dota', 'Copey'),
-- CANTON 118: CURRIDABAT
('11801', '1', '18', '01', 'San José', 'Curridabat', 'Curridabat'),
('11802', '1', '18', '02', 'San José', 'Curridabat', 'Granadilla'),
('11803', '1', '18', '03', 'San José', 'Curridabat', 'Sánchez'),
('11804', '1', '18', '04', 'San José', 'Curridabat', 'Tirrases'),
-- CANTON 119: PEREZ ZELEDON
('11901', '1', '19', '01', 'San José', 'Pérez Zeledón', 'San Isidro'),
('11902', '1', '19', '02', 'San José', 'Pérez Zeledón', 'General'),
('11903', '1', '19', '03', 'San José', 'Pérez Zeledón', 'Daniel Flores'),
('11904', '1', '19', '04', 'San José', 'Pérez Zeledón', 'Rivas'),
('11905', '1', '19', '05', 'San José', 'Pérez Zeledón', 'San Pedro'),
('11906', '1', '19', '06', 'San José', 'Pérez Zeledón', 'Platanares'),
('11907', '1', '19', '07', 'San José', 'Pérez Zeledón', 'Pejibaye'),
('11908', '1', '19', '08', 'San José', 'Pérez Zeledón', 'Cajón o Carmen'),
('11909', '1', '19', '09', 'San José', 'Pérez Zeledón', 'Barú'),
('11910', '1', '19', '10', 'San José', 'Pérez Zeledón', 'Río Nuevo'),
('11911', '1', '19', '11', 'San José', 'Pérez Zeledón', 'Páramo'),
-- CANTON 120: LEON CORTES
('12001', '1', '20', '01', 'San José', 'León Cortés', 'San Pablo'),
('12002', '1', '20', '02', 'San José', 'León Cortés', 'San Andrés'),
('12003', '1', '20', '03', 'San José', 'León Cortés', 'Llano Bonito'),
('12004', '1', '20', '04', 'San José', 'León Cortés', 'San Isidro'),
('12005', '1', '20', '05', 'San José', 'León Cortés', 'Santa Cruz'),
('12006', '1', '20', '06', 'San José', 'León Cortés', 'San Antonio'),

-- PROVINCIA 2: ALAJUELA
-- CANTON 201: ALAJUELA
('20101', '2', '01', '01', 'Alajuela', 'Alajuela', 'Alajuela'),
('20102', '2', '01', '02', 'Alajuela', 'Alajuela', 'San José'),
('20103', '2', '01', '03', 'Alajuela', 'Alajuela', 'Carrizal'),
('20104', '2', '01', '04', 'Alajuela', 'Alajuela', 'San Antonio'),
('20105', '2', '01', '05', 'Alajuela', 'Alajuela', 'Guácima'),
('20106', '2', '01', '06', 'Alajuela', 'Alajuela', 'San Isidro'),
('20107', '2', '01', '07', 'Alajuela', 'Alajuela', 'Sabanilla'),
('20108', '2', '01', '08', 'Alajuela', 'Alajuela', 'San Rafael'),
('20109', '2', '01', '09', 'Alajuela', 'Alajuela', 'Río Segundo'),
('20110', '2', '01', '10', 'Alajuela', 'Alajuela', 'Desamparados'),
('20111', '2', '01', '11', 'Alajuela', 'Alajuela', 'Turrucares'),
('20112', '2', '01', '12', 'Alajuela', 'Alajuela', 'Tambor'),
('20113', '2', '01', '13', 'Alajuela', 'Alajuela', 'La Garita'),
('20114', '2', '01', '14', 'Alajuela', 'Alajuela', 'Sarapiquí'),
-- CANTON 202: SAN RAMON
('20201', '2', '02', '01', 'Alajuela', 'San Ramón', 'San Ramón'),
('20202', '2', '02', '02', 'Alajuela', 'San Ramón', 'Santiago'),
('20203', '2', '02', '03', 'Alajuela', 'San Ramón', 'San Juan'),
('20204', '2', '02', '04', 'Alajuela', 'San Ramón', 'Piedades Norte'),
('20205', '2', '02', '05', 'Alajuela', 'San Ramón', 'Piedades Sur'),
('20206', '2', '02', '06', 'Alajuela', 'San Ramón', 'San Rafael'),
('20207', '2', '02', '07', 'Alajuela', 'San Ramón', 'San Isidro'),
('20208', '2', '02', '08', 'Alajuela', 'San Ramón', 'Ángeles'),
('20209', '2', '02', '09', 'Alajuela', 'San Ramón', 'Alfaro'),
('20210', '2', '02', '10', 'Alajuela', 'San Ramón', 'Volio'),
('20211', '2', '02', '11', 'Alajuela', 'San Ramón', 'Concepción'),
('20212', '2', '02', '12', 'Alajuela', 'San Ramón', 'Zapotal'),
('20213', '2', '02', '13', 'Alajuela', 'San Ramón', 'San Isidro de Peñas Blancas'),
-- CANTON 203: GRECIA
('20301', '2', '03', '01', 'Alajuela', 'Grecia', 'Grecia'),
('20302', '2', '03', '02', 'Alajuela', 'Grecia', 'San Isidro'),
('20303', '2', '03', '03', 'Alajuela', 'Grecia', 'San José'),
('20304', '2', '03', '04', 'Alajuela', 'Grecia', 'San Roque'),
('20305', '2', '03', '05', 'Alajuela', 'Grecia', 'Tácares'),
('20306', '2', '03', '06', 'Alajuela', 'Grecia', 'Río Cuarto'),
('20307', '2', '03', '07', 'Alajuela', 'Grecia', 'Puente Piedra'),
('20308', '2', '03', '08', 'Alajuela', 'Grecia', 'Bolívar'),
-- CANTON 204: SAN MATEO
('20401', '2', '04', '01', 'Alajuela', 'San Mateo', 'San Mateo'),
('20402', '2', '04', '02', 'Alajuela', 'San Mateo', 'Desmonte'),
('20403', '2', '04', '03', 'Alajuela', 'San Mateo', 'Jesús María'),
-- CANTON 205: ATENAS
('20501', '2', '05', '01', 'Alajuela', 'Atenas', 'Atenas'),
('20502', '2', '05', '02', 'Alajuela', 'Atenas', 'Jesús'),
('20503', '2', '05', '03', 'Alajuela', 'Atenas', 'Mercedes'),
('20504', '2', '05', '04', 'Alajuela', 'Atenas', 'San Isidro'),
('20505', '2', '05', '05', 'Alajuela', 'Atenas', 'Concepción'),
('20506', '2', '05', '06', 'Alajuela', 'Atenas', 'San José'),
('20507', '2', '05', '07', 'Alajuela', 'Atenas', 'Santa Eulalia'),
('20508', '2', '05', '08', 'Alajuela', 'Atenas', 'Escobal'),
-- CANTON 206: NARANJO
('20601', '2', '06', '01', 'Alajuela', 'Naranjo', 'Naranjo'),
('20602', '2', '06', '02', 'Alajuela', 'Naranjo', 'San Miguel'),
('20603', '2', '06', '03', 'Alajuela', 'Naranjo', 'San José'),
('20604', '2', '06', '04', 'Alajuela', 'Naranjo', 'Cirrí Sur'),
('20605', '2', '06', '05', 'Alajuela', 'Naranjo', 'San Jerónimo'),
('20606', '2', '06', '06', 'Alajuela', 'Naranjo', 'San Juan'),
('20607', '2', '06', '07', 'Alajuela', 'Naranjo', 'Rosario'),
-- CANTON 207: PALMARES
('20701', '2', '07', '01', 'Alajuela', 'Palmares', 'Palmares'),
('20702', '2', '07', '02', 'Alajuela', 'Palmares', 'Zaragoza'),
('20703', '2', '07', '03', 'Alajuela', 'Palmares', 'Buenos Aires'),
('20704', '2', '07', '04', 'Alajuela', 'Palmares', 'Santiago'),
('20705', '2', '07', '05', 'Alajuela', 'Palmares', 'Candelaria'),
('20706', '2', '07', '06', 'Alajuela', 'Palmares', 'Esquipulas'),
('20707', '2', '07', '07', 'Alajuela', 'Palmares', 'La Granja'),
-- CANTON 208: POAS
('20801', '2', '08', '01', 'Alajuela', 'Poás', 'San Pedro'),
('20802', '2', '08', '02', 'Alajuela', 'Poás', 'San Juan'),
('20803', '2', '08', '03', 'Alajuela', 'Poás', 'San Rafael'),
('20804', '2', '08', '04', 'Alajuela', 'Poás', 'Carrillos'),
('20805', '2', '08', '05', 'Alajuela', 'Poás', 'Sabana Redonda'),
-- CANTON 209: OROTINA
('20901', '2', '09', '01', 'Alajuela', 'Orotina', 'Orotina'),
('20902', '2', '09', '02', 'Alajuela', 'Orotina', 'Mastate'),
('20903', '2', '09', '03', 'Alajuela', 'Orotina', 'Hacienda Vieja'),
('20904', '2', '09', '04', 'Alajuela', 'Orotina', 'Coyolar'),
('20905', '2', '09', '05', 'Alajuela', 'Orotina', 'Ceiba'),
-- CANTON 210: SAN CARLOS
('21001', '2', '10', '01', 'Alajuela', 'San Carlos', 'Quesada'),
('21002', '2', '10', '02', 'Alajuela', 'San Carlos', 'Florencia'),
('21003', '2', '10', '03', 'Alajuela', 'San Carlos', 'Buenavista'),
('21004', '2', '10', '04', 'Alajuela', 'San Carlos', 'Aguas Zarcas'),
('21005', '2', '10', '05', 'Alajuela', 'San Carlos', 'Venecia'),
('21006', '2', '10', '06', 'Alajuela', 'San Carlos', 'Pital'),
('21007', '2', '10', '07', 'Alajuela', 'San Carlos', 'Fortuna'),
('21008', '2', '10', '08', 'Alajuela', 'San Carlos', 'Tigra'),
('21009', '2', '10', '09', 'Alajuela', 'San Carlos', 'Palmera'),
('21010', '2', '10', '10', 'Alajuela', 'San Carlos', 'Venado'),
('21011', '2', '10', '11', 'Alajuela', 'San Carlos', 'Cutris'),
('21012', '2', '10', '12', 'Alajuela', 'San Carlos', 'Monterrey'),
('21013', '2', '10', '13', 'Alajuela', 'San Carlos', 'Pocosol'),
-- CANTON 211: ALFARO RUIZ
('21101', '2', '11', '01', 'Alajuela', 'Alfaro Ruiz', 'Zarcero'),
('21102', '2', '11', '02', 'Alajuela', 'Alfaro Ruiz', 'Laguna'),
('21103', '2', '11', '03', 'Alajuela', 'Alfaro Ruiz', 'Tapezco'),
('21104', '2', '11', '04', 'Alajuela', 'Alfaro Ruiz', 'Guadalupe'),
('21105', '2', '11', '05', 'Alajuela', 'Alfaro Ruiz', 'Palmira'),
('21106', '2', '11', '06', 'Alajuela', 'Alfaro Ruiz', 'Zapote'),
('21107', '2', '11', '07', 'Alajuela', 'Alfaro Ruiz', 'Brisas'),
-- CANTON 212: VALVERDE VEGA
('21201', '2', '12', '01', 'Alajuela', 'Valverde Vega', 'Sarchí Norte'),
('21202', '2', '12', '02', 'Alajuela', 'Valverde Vega', 'Sarchí Sur'),
('21203', '2', '12', '03', 'Alajuela', 'Valverde Vega', 'Toro Amarillo'),
('21204', '2', '12', '04', 'Alajuela', 'Valverde Vega', 'San Pedro'),
('21205', '2', '12', '05', 'Alajuela', 'Valverde Vega', 'Rodríguez'),
-- CANTON 213: UPALA
('21301', '2', '13', '01', 'Alajuela', 'Upala', 'Upala'),
('21302', '2', '13', '02', 'Alajuela', 'Upala', 'Aguas Claras'),
('21303', '2', '13', '03', 'Alajuela', 'Upala', 'San José o Pizote'),
('21304', '2', '13', '04', 'Alajuela', 'Upala', 'Bijagua'),
('21305', '2', '13', '05', 'Alajuela', 'Upala', 'Delicias'),
('21306', '2', '13', '06', 'Alajuela', 'Upala', 'Dos Ríos'),
('21307', '2', '13', '07', 'Alajuela', 'Upala', 'Yolillal'),
-- CANTON 214: LOS CHILES
('21401', '2', '14', '01', 'Alajuela', 'Los Chiles', 'Los Chiles'),
('21402', '2', '14', '02', 'Alajuela', 'Los Chiles', 'Caño Negro'),
('21403', '2', '14', '03', 'Alajuela', 'Los Chiles', 'Amparo'),
('21404', '2', '14', '04', 'Alajuela', 'Los Chiles', 'San Jorge'),
-- CANTON 215: GUATUSO
('21501', '2', '15', '01', 'Alajuela', 'Guatuso', 'San Rafael'),
('21502', '2', '15', '02', 'Alajuela', 'Guatuso', 'Buenavista'),
('21503', '2', '15', '03', 'Alajuela', 'Guatuso', 'Cote'),

-- PROVINCIA 3: CARTAGO
-- CANTON 301: CARTAGO
('30101', '3', '01', '01', 'Cartago', 'Cartago', 'Oriental'),
('30102', '3', '01', '02', 'Cartago', 'Cartago', 'Occidental'),
('30103', '3', '01', '03', 'Cartago', 'Cartago', 'Carmen'),
('30104', '3', '01', '04', 'Cartago', 'Cartago', 'San Nicolás'),
('30105', '3', '01', '05', 'Cartago', 'Cartago', 'Aguacaliente (San Francisco)'),
('30106', '3', '01', '06', 'Cartago', 'Cartago', 'Guadalupe (Arenilla)'),
('30107', '3', '01', '07', 'Cartago', 'Cartago', 'Corralillo'),
('30108', '3', '01', '08', 'Cartago', 'Cartago', 'Tierra Blanca'),
('30109', '3', '01', '09', 'Cartago', 'Cartago', 'Dulce Nombre'),
('30110', '3', '01', '10', 'Cartago', 'Cartago', 'Llano Grande'),
('30111', '3', '01', '11', 'Cartago', 'Cartago', 'Quebradilla'),
-- CANTON 302: PARAISO
('30201', '3', '02', '01', 'Cartago', 'Paraíso', 'Paraíso'),
('30202', '3', '02', '02', 'Cartago', 'Paraíso', 'Santiago'),
('30203', '3', '02', '03', 'Cartago', 'Paraíso', 'Orosi'),
('30204', '3', '02', '04', 'Cartago', 'Paraíso', 'Cachí'),
('30205', '3', '02', '05', 'Cartago', 'Paraíso', 'Llanos de Sta Lucia'),
-- CANTON 303: LA UNION
('30301', '3', '03', '01', 'Cartago', 'La Unión', 'Tres Ríos'),
('30302', '3', '03', '02', 'Cartago', 'La Unión', 'San Diego'),
('30303', '3', '03', '03', 'Cartago', 'La Unión', 'San Juan'),
('30304', '3', '03', '04', 'Cartago', 'La Unión', 'San Rafael'),
('30305', '3', '03', '05', 'Cartago', 'La Unión', 'Concepción'),
('30306', '3', '03', '06', 'Cartago', 'La Unión', 'Dulce Nombre'),
('30307', '3', '03', '07', 'Cartago', 'La Unión', 'San Ramón'),
('30308', '3', '03', '08', 'Cartago', 'La Unión', 'Río Azul'),
-- CANTON 304: JIMENEZ
('30401', '3', '04', '01', 'Cartago', 'Jiménez', 'Juan Viñas'),
('30402', '3', '04', '02', 'Cartago', 'Jiménez', 'Tucurrique'),
('30403', '3', '04', '03', 'Cartago', 'Jiménez', 'Pejibaye'),
-- CANTON 305: TURRIALBA
('30501', '3', '05', '01', 'Cartago', 'Turrialba', 'Turrialba'),
('30502', '3', '05', '02', 'Cartago', 'Turrialba', 'La Suiza'),
('30503', '3', '05', '03', 'Cartago', 'Turrialba', 'Peralta'),
('30504', '3', '05', '04', 'Cartago', 'Turrialba', 'Santa Cruz'),
('30505', '3', '05', '05', 'Cartago', 'Turrialba', 'Santa Teresita'),
('30506', '3', '05', '06', 'Cartago', 'Turrialba', 'Pavones'),
('30507', '3', '05', '07', 'Cartago', 'Turrialba', 'Tuis'),
('30508', '3', '05', '08', 'Cartago', 'Turrialba', 'Tayutic'),
('30509', '3', '05', '09', 'Cartago', 'Turrialba', 'Santa Rosa'),
('30510', '3', '05', '10', 'Cartago', 'Turrialba', 'Tres Equis'),
('30511', '3', '05', '11', 'Cartago', 'Turrialba', 'La Isabel'),
('30512', '3', '05', '12', 'Cartago', 'Turrialba', 'Chirripo'),
-- CANTON 306: ALVARADO
('30601', '3', '06', '01', 'Cartago', 'Alvarado', 'Pacayas'),
('30602', '3', '06', '02', 'Cartago', 'Alvarado', 'Cervantes'),
('30603', '3', '06', '03', 'Cartago', 'Alvarado', 'Capellades'),
-- CANTON 307: OREAMUNO
('30701', '3', '07', '01', 'Cartago', 'Oreamuno', 'San Rafael'),
('30702', '3', '07', '02', 'Cartago', 'Oreamuno', 'Cot'),
('30703', '3', '07', '03', 'Cartago', 'Oreamuno', 'Potrero Cerrado'),
('30704', '3', '07', '04', 'Cartago', 'Oreamuno', 'Cipreses'),
('30705', '3', '07', '05', 'Cartago', 'Oreamuno', 'Santa Rosa'),
-- CANTON 308: EL GUARCO
('30801', '3', '08', '01', 'Cartago', 'El Guarco', 'El Tejar'),
('30802', '3', '08', '02', 'Cartago', 'El Guarco', 'San Isidro'),
('30803', '3', '08', '03', 'Cartago', 'El Guarco', 'Tobosi'),
('30804', '3', '08', '04', 'Cartago', 'El Guarco', 'Patio de Agua'),

-- PROVINCIA 4: HEREDIA
-- CANTON 401: HEREDIA
('40101', '4', '01', '01', 'Heredia', 'Heredia', 'Heredia'),
('40102', '4', '01', '02', 'Heredia', 'Heredia', 'Mercedes'),
('40103', '4', '01', '03', 'Heredia', 'Heredia', 'San Francisco'),
('40104', '4', '01', '04', 'Heredia', 'Heredia', 'Ulloa'),
('40105', '4', '01', '05', 'Heredia', 'Heredia', 'Vara Blanca'),
-- CANTON 402: BARVA
('40201', '4', '02', '01', 'Heredia', 'Barva', 'Barva'),
('40202', '4', '02', '02', 'Heredia', 'Barva', 'San Pedro'),
('40203', '4', '02', '03', 'Heredia', 'Barva', 'San Pablo'),
('40204', '4', '02', '04', 'Heredia', 'Barva', 'San Roque'),
('40205', '4', '02', '05', 'Heredia', 'Barva', 'Santa Lucía'),
('40206', '4', '02', '06', 'Heredia', 'Barva', 'San José de la Montaña'),
-- CANTON 403: SANTO DOMINGO
('40301', '4', '03', '01', 'Heredia', 'Santo Domingo', 'Santo Domingo'),
('40302', '4', '03', '02', 'Heredia', 'Santo Domingo', 'San Vicente'),
('40303', '4', '03', '03', 'Heredia', 'Santo Domingo', 'San Miguel'),
('40304', '4', '03', '04', 'Heredia', 'Santo Domingo', 'Paracito'),
('40305', '4', '03', '05', 'Heredia', 'Santo Domingo', 'Santo Tomás'),
('40306', '4', '03', '06', 'Heredia', 'Santo Domingo', 'Santa Rosa'),
('40307', '4', '03', '07', 'Heredia', 'Santo Domingo', 'Tures'),
('40308', '4', '03', '08', 'Heredia', 'Santo Domingo', 'Pará'),
-- CANTON 404: SANTA BARBARA
('40401', '4', '04', '01', 'Heredia', 'Santa Bárbara', 'Santa Bárbara'),
('40402', '4', '04', '02', 'Heredia', 'Santa Bárbara', 'San Pedro'),
('40403', '4', '04', '03', 'Heredia', 'Santa Bárbara', 'San Juan'),
('40404', '4', '04', '04', 'Heredia', 'Santa Bárbara', 'Jesús'),
('40405', '4', '04', '05', 'Heredia', 'Santa Bárbara', 'Santo Domingo del Roble'),
('40406', '4', '04', '06', 'Heredia', 'Santa Bárbara', 'Puraba'),
-- CANTON 405: SAN RAFAEL
('40501', '4', '05', '01', 'Heredia', 'San Rafael', 'San Rafael'),
('40502', '4', '05', '02', 'Heredia', 'San Rafael', 'San Josecito'),
('40503', '4', '05', '03', 'Heredia', 'San Rafael', 'Santiago'),
('40504', '4', '05', '04', 'Heredia', 'San Rafael', 'Ángeles'),
('40505', '4', '05', '05', 'Heredia', 'San Rafael', 'Concepción'),
-- CANTON 406: SAN ISIDRO
('40601', '4', '06', '01', 'Heredia', 'San Isidro', 'San Isidro'),
('40602', '4', '06', '02', 'Heredia', 'San Isidro', 'San José'),
('40603', '4', '06', '03', 'Heredia', 'San Isidro', 'Concepción'),
('40604', '4', '06', '04', 'Heredia', 'San Isidro', 'San Francisco'),
-- CANTON 407: BELEN
('40701', '4', '07', '01', 'Heredia', 'Belén', 'San Antonio'),
('40702', '4', '07', '02', 'Heredia', 'Belén', 'La Rivera'),
('40703', '4', '07', '03', 'Heredia', 'Belén', 'Asunción'),
-- CANTON 408: FLORES
('40801', '4', '08', '01', 'Heredia', 'Flores', 'San Joaquín'),
('40802', '4', '08', '02', 'Heredia', 'Flores', 'Barrantes'),
('40803', '4', '08', '03', 'Heredia', 'Flores', 'Llorente'),
-- CANTON 409: SAN PABLO
('40901', '4', '09', '01', 'Heredia', 'San Pablo', 'San Pablo'),
-- CANTON 410: SARAPIQUI
('41001', '4', '10', '01', 'Heredia', 'Sarapiquí', 'Puerto Viejo'),
('41002', '4', '10', '02', 'Heredia', 'Sarapiquí', 'La Virgen'),
('41003', '4', '10', '03', 'Heredia', 'Sarapiquí', 'Horquetas'),
('41004', '4', '10', '04', 'Heredia', 'Sarapiquí', 'Llanuras del Gaspar'),
('41005', '4', '10', '05', 'Heredia', 'Sarapiquí', 'Cureña'),

-- PROVINCIA 5: GUANACASTE
-- CANTON 501: LIBERIA
('50101', '5', '01', '01', 'Guanacaste', 'Liberia', 'Liberia'),
('50102', '5', '01', '02', 'Guanacaste', 'Liberia', 'Cañas Dulces'),
('50103', '5', '01', '03', 'Guanacaste', 'Liberia', 'Mayorga'),
('50104', '5', '01', '04', 'Guanacaste', 'Liberia', 'Nacascolo'),
('50105', '5', '01', '05', 'Guanacaste', 'Liberia', 'Curubande'),
-- CANTON 502: NICOYA
('50201', '5', '02', '01', 'Guanacaste', 'Nicoya', 'Nicoya'),
('50202', '5', '02', '02', 'Guanacaste', 'Nicoya', 'Mansión'),
('50203', '5', '02', '03', 'Guanacaste', 'Nicoya', 'San Antonio'),
('50204', '5', '02', '04', 'Guanacaste', 'Nicoya', 'Quebrada Honda'),
('50205', '5', '02', '05', 'Guanacaste', 'Nicoya', 'Sámara'),
('50206', '5', '02', '06', 'Guanacaste', 'Nicoya', 'Nosara'),
('50207', '5', '02', '07', 'Guanacaste', 'Nicoya', 'Belén de Nosarita'),
-- CANTON 503: SANTA CRUZ
('50301', '5', '03', '01', 'Guanacaste', 'Santa Cruz', 'Santa Cruz'),
('50302', '5', '03', '02', 'Guanacaste', 'Santa Cruz', 'Bolsón'),
('50303', '5', '03', '03', 'Guanacaste', 'Santa Cruz', 'Veintisiete de Abril'),
('50304', '5', '03', '04', 'Guanacaste', 'Santa Cruz', 'Tempate'),
('50305', '5', '03', '05', 'Guanacaste', 'Santa Cruz', 'Cartagena'),
('50306', '5', '03', '06', 'Guanacaste', 'Santa Cruz', 'Cuajiniquil'),
('50307', '5', '03', '07', 'Guanacaste', 'Santa Cruz', 'Diriá'),
('50308', '5', '03', '08', 'Guanacaste', 'Santa Cruz', 'Cabo Velas'),
('50309', '5', '03', '09', 'Guanacaste', 'Santa Cruz', 'Tamarindo'),
-- CANTON 504: BAGACES
('50401', '5', '04', '01', 'Guanacaste', 'Bagaces', 'Bagaces'),
('50402', '5', '04', '02', 'Guanacaste', 'Bagaces', 'Fortuna'),
('50403', '5', '04', '03', 'Guanacaste', 'Bagaces', 'Mogote'),
('50404', '5', '04', '04', 'Guanacaste', 'Bagaces', 'Río Naranjo'),
-- CANTON 505: CARRILLO
('50501', '5', '05', '01', 'Guanacaste', 'Carrillo', 'Filadelfia'),
('50502', '5', '05', '02', 'Guanacaste', 'Carrillo', 'Palmira'),
('50503', '5', '05', '03', 'Guanacaste', 'Carrillo', 'Sardinal'),
('50504', '5', '05', '04', 'Guanacaste', 'Carrillo', 'Belén'),
-- CANTON 506: CAÑAS
('50601', '5', '06', '01', 'Guanacaste', 'Cañas', 'Cañas'),
('50602', '5', '06', '02', 'Guanacaste', 'Cañas', 'Palmira'),
('50603', '5', '06', '03', 'Guanacaste', 'Cañas', 'San Miguel'),
('50604', '5', '06', '04', 'Guanacaste', 'Cañas', 'Bebedero'),
('50605', '5', '06', '05', 'Guanacaste', 'Cañas', 'Porozal'),
-- CANTON 507: ABANGARES
('50701', '5', '07', '01', 'Guanacaste', 'Abangares', 'Juntas'),
('50702', '5', '07', '02', 'Guanacaste', 'Abangares', 'Sierra'),
('50703', '5', '07', '03', 'Guanacaste', 'Abangares', 'San Juan'),
('50704', '5', '07', '04', 'Guanacaste', 'Abangares', 'Colorado'),
-- CANTON 508: TILARAN
('50801', '5', '08', '01', 'Guanacaste', 'Tilarán', 'Tilarán'),
('50802', '5', '08', '02', 'Guanacaste', 'Tilarán', 'Quebrada Grande'),
('50803', '5', '08', '03', 'Guanacaste', 'Tilarán', 'Tronadora'),
('50804', '5', '08', '04', 'Guanacaste', 'Tilarán', 'Santa Rosa'),
('50805', '5', '08', '05', 'Guanacaste', 'Tilarán', 'Líbano'),
('50806', '5', '08', '06', 'Guanacaste', 'Tilarán', 'Tierras Morenas'),
('50807', '5', '08', '07', 'Guanacaste', 'Tilarán', 'Arenal'),
-- CANTON 509: NANDAYURE
('50901', '5', '09', '01', 'Guanacaste', 'Nandayure', 'Carmona'),
('50902', '5', '09', '02', 'Guanacaste', 'Nandayure', 'Santa Rita'),
('50903', '5', '09', '03', 'Guanacaste', 'Nandayure', 'Zapotal'),
('50904', '5', '09', '04', 'Guanacaste', 'Nandayure', 'San Pablo'),
('50905', '5', '09', '05', 'Guanacaste', 'Nandayure', 'Porvenir'),
('50906', '5', '09', '06', 'Guanacaste', 'Nandayure', 'Bejuco'),
-- CANTON 510: LA CRUZ
('51001', '5', '10', '01', 'Guanacaste', 'La Cruz', 'La Cruz'),
('51002', '5', '10', '02', 'Guanacaste', 'La Cruz', 'Santa Cecilia'),
('51003', '5', '10', '03', 'Guanacaste', 'La Cruz', 'Garita'),
('51004', '5', '10', '04', 'Guanacaste', 'La Cruz', 'Santa Elena'),
-- CANTON 511: HOJANCHA
('51101', '5', '11', '01', 'Guanacaste', 'Hojancha', 'Hojancha'),
('51102', '5', '11', '02', 'Guanacaste', 'Hojancha', 'Monte Romo'),
('51103', '5', '11', '03', 'Guanacaste', 'Hojancha', 'Puerto Carrillo'),
('51104', '5', '11', '04', 'Guanacaste', 'Hojancha', 'Huacas'),

-- PROVINCIA 6: PUNTARENAS
-- CANTON 601: PUNTARENAS
('60101', '6', '01', '01', 'Puntarenas', 'Puntarenas', 'Puntarenas'),
('60102', '6', '01', '02', 'Puntarenas', 'Puntarenas', 'Pitahaya'),
('60103', '6', '01', '03', 'Puntarenas', 'Puntarenas', 'Chomes'),
('60104', '6', '01', '04', 'Puntarenas', 'Puntarenas', 'Lepanto'),
('60105', '6', '01', '05', 'Puntarenas', 'Puntarenas', 'Paquera'),
('60106', '6', '01', '06', 'Puntarenas', 'Puntarenas', 'Manzanillo'),
('60107', '6', '01', '07', 'Puntarenas', 'Puntarenas', 'Guacimal'),
('60108', '6', '01', '08', 'Puntarenas', 'Puntarenas', 'Barranca'),
('60109', '6', '01', '09', 'Puntarenas', 'Puntarenas', 'Monte Verde'),
('60110', '6', '01', '10', 'Puntarenas', 'Puntarenas', 'Isla del Coco'),
('60111', '6', '01', '11', 'Puntarenas', 'Puntarenas', 'Cóbano'),
('60112', '6', '01', '12', 'Puntarenas', 'Puntarenas', 'Chacarita'),
('60113', '6', '01', '13', 'Puntarenas', 'Puntarenas', 'Chira (Isla)'),
('60114', '6', '01', '14', 'Puntarenas', 'Puntarenas', 'Acapulco'),
('60115', '6', '01', '15', 'Puntarenas', 'Puntarenas', 'El Roble'),
('60116', '6', '01', '16', 'Puntarenas', 'Puntarenas', 'Arancibia'),
-- CANTON 602: ESPARZA
('60201', '6', '02', '01', 'Puntarenas', 'Esparza', 'Espíritu Santo'),
('60202', '6', '02', '02', 'Puntarenas', 'Esparza', 'San Juan Grande'),
('60203', '6', '02', '03', 'Puntarenas', 'Esparza', 'Macacona'),
('60204', '6', '02', '04', 'Puntarenas', 'Esparza', 'San Rafael'),
('60205', '6', '02', '05', 'Puntarenas', 'Esparza', 'San Jerónimo'),
-- CANTON 603: BUENOS AIRES
('60301', '6', '03', '01', 'Puntarenas', 'Buenos Aires', 'Buenos Aires'),
('60302', '6', '03', '02', 'Puntarenas', 'Buenos Aires', 'Volcán'),
('60303', '6', '03', '03', 'Puntarenas', 'Buenos Aires', 'Potrero Grande'),
('60304', '6', '03', '04', 'Puntarenas', 'Buenos Aires', 'Boruca'),
('60305', '6', '03', '05', 'Puntarenas', 'Buenos Aires', 'Pilas'),
('60306', '6', '03', '06', 'Puntarenas', 'Buenos Aires', 'Colinas o Bajo de Maíz'),
('60307', '6', '03', '07', 'Puntarenas', 'Buenos Aires', 'Chánguena'),
('60308', '6', '03', '08', 'Puntarenas', 'Buenos Aires', 'Bioley'),
('60309', '6', '03', '09', 'Puntarenas', 'Buenos Aires', 'Brunka'),
-- CANTON 604: MONTES DE ORO
('60401', '6', '04', '01', 'Puntarenas', 'Montes de Oro', 'Miramar'),
('60402', '6', '04', '02', 'Puntarenas', 'Montes de Oro', 'Unión'),
('60403', '6', '04', '03', 'Puntarenas', 'Montes de Oro', 'San Isidro'),
-- CANTON 605: OSA
('60501', '6', '05', '01', 'Puntarenas', 'Osa', 'Puerto Cortés'),
('60502', '6', '05', '02', 'Puntarenas', 'Osa', 'Palmar'),
('60503', '6', '05', '03', 'Puntarenas', 'Osa', 'Sierpe'),
('60504', '6', '05', '04', 'Puntarenas', 'Osa', 'Bahía Ballena'),
('60505', '6', '05', '05', 'Puntarenas', 'Osa', 'Piedras Blancas'),
-- CANTON 606: AGUIRRE
('60601', '6', '06', '01', 'Puntarenas', 'Aguirre', 'Quepos'),
('60602', '6', '06', '02', 'Puntarenas', 'Aguirre', 'Savegre'),
('60603', '6', '06', '03', 'Puntarenas', 'Aguirre', 'Naranjito'),
-- CANTON 607: GOLFITO
('60701', '6', '07', '01', 'Puntarenas', 'Golfito', 'Golfito'),
('60702', '6', '07', '02', 'Puntarenas', 'Golfito', 'Puerto Jiménez'),
('60703', '6', '07', '03', 'Puntarenas', 'Golfito', 'Guaycará'),
('60704', '6', '07', '04', 'Puntarenas', 'Golfito', 'Pavones o Villa Conte'),
-- CANTON 608: COTO BRUS
('60801', '6', '08', '01', 'Puntarenas', 'Coto Brus', 'San Vito'),
('60802', '6', '08', '02', 'Puntarenas', 'Coto Brus', 'Sabalito'),
('60803', '6', '08', '03', 'Puntarenas', 'Coto Brus', 'Agua Buena'),
('60804', '6', '08', '04', 'Puntarenas', 'Coto Brus', 'Limoncito'),
('60805', '6', '08', '05', 'Puntarenas', 'Coto Brus', 'Pittier'),
-- CANTON 609: PARRITA
('60901', '6', '09', '01', 'Puntarenas', 'Parrita', 'Parrita'),
-- CANTON 610: CORREDORES
('61001', '6', '10', '01', 'Puntarenas', 'Corredores', 'Corredores'),
('61002', '6', '10', '02', 'Puntarenas', 'Corredores', 'La Cuesta'),
('61003', '6', '10', '03', 'Puntarenas', 'Corredores', 'Paso Canoas'),
('61004', '6', '10', '04', 'Puntarenas', 'Corredores', 'Laurel'),
-- CANTON 611: GARABITO
('61101', '6', '11', '01', 'Puntarenas', 'Garabito', 'Jacó'),
('61102', '6', '11', '02', 'Puntarenas', 'Garabito', 'Tárcoles'),

-- PROVINCIA 7: LIMON
-- CANTON 701: LIMON
('70101', '7', '01', '01', 'Limón', 'Limón', 'Limón'),
('70102', '7', '01', '02', 'Limón', 'Limón', 'Valle La Estrella'),
('70103', '7', '01', '03', 'Limón', 'Limón', 'Río Blanco'),
('70104', '7', '01', '04', 'Limón', 'Limón', 'Matama'),
-- CANTON 702: POCOCI
('70201', '7', '02', '01', 'Limón', 'Pococí', 'Guápiles'),
('70202', '7', '02', '02', 'Limón', 'Pococí', 'Jiménez'),
('70203', '7', '02', '03', 'Limón', 'Pococí', 'Rita'),
('70204', '7', '02', '04', 'Limón', 'Pococí', 'Roxana'),
('70205', '7', '02', '05', 'Limón', 'Pococí', 'Cariari'),
('70206', '7', '02', '06', 'Limón', 'Pococí', 'Colorado'),
-- CANTON 703: SIQUIRRES
('70301', '7', '03', '01', 'Limón', 'Siquirres', 'Siquirres'),
('70302', '7', '03', '02', 'Limón', 'Siquirres', 'Pacuarito'),
('70303', '7', '03', '03', 'Limón', 'Siquirres', 'Florida'),
('70304', '7', '03', '04', 'Limón', 'Siquirres', 'Germania'),
('70305', '7', '03', '05', 'Limón', 'Siquirres', 'Cairo'),
('70306', '7', '03', '06', 'Limón', 'Siquirres', 'Alegría'),
-- CANTON 704: TALAMANCA
('70401', '7', '04', '01', 'Limón', 'Talamanca', 'Bratsi'),
('70402', '7', '04', '02', 'Limón', 'Talamanca', 'Sixaola'),
('70403', '7', '04', '03', 'Limón', 'Talamanca', 'Cahuita'),
('70404', '7', '04', '04', 'Limón', 'Talamanca', 'Telire'),
-- CANTON 705: MATINA
('70501', '7', '05', '01', 'Limón', 'Matina', 'Matina'),
('70502', '7', '05', '02', 'Limón', 'Matina', 'Batán'),
('70503', '7', '05', '03', 'Limón', 'Matina', 'Carrandí'),
-- CANTON 706: GUACIMO
('70601', '7', '06', '01', 'Limón', 'Guácimo', 'Guácimo'),
('70602', '7', '06', '02', 'Limón', 'Guácimo', 'Mercedes'),
('70603', '7', '06', '03', 'Limón', 'Guácimo', 'Pocora'),
('70604', '7', '06', '04', 'Limón', 'Guácimo', 'Río Jiménez'),
('70605', '7', '06', '05', 'Limón', 'Guácimo', 'Duacari')
ON CONFLICT (codigo) DO NOTHING;

COMMIT;
