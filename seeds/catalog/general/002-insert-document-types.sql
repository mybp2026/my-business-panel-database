SET SEARCH_PATH TO general_schema;

INSERT INTO general_schema.document_type(type_name, description, ident_code) VALUES
    ('Cedula Fisica', 'Tarjeta de identificacion en fisico', '01'),
    ('Cedula Juridica', 'Numero de identificacion asignado por el Registro Nacional', '02'),
    ('DIMEX', 'Documento de Identidad Migratorio para Extranjeros', '03'),
    ('NITE', 'Numero de Identificacion Tributaria Especial', '04'),
    ('Extranjero No Domiciliado', 'Cliente o proveedor sin residencia en el pais', '05'),
    ('No Contribuyente', 'Persona no inscrita en el DGT', '06')
ON CONFLICT DO NOTHING;