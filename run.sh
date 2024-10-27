#!/bin/bash

# Variables
PROJECT_NAME="MiApiSQL"
CONTAINER_NAME="mi-api-sql"
DB_CONNECTION_STRING="Server=tcp:ec2-54-161-11-166.compute-1.amazonaws.com,1433;Database=AdventureWorks2019;User Id=SA;Password=YourStrong@Passw0rd;Encrypt=False;"

# Crear la estructura de archivos del proyecto
mkdir $PROJECT_NAME
cd $PROJECT_NAME

# Crear el modelo Producto con el namespace correcto
mkdir -p Models
cat <<EOL > Models/Producto.cs
namespace $PROJECT_NAME.Models
{
    public class Producto
    {
        public int ProductID { get; set; }
        public string Name { get; set; }
        public string ProductNumber { get; set; }
        public string Color { get; set; }
        public decimal StandardCost { get; set; }
    }
}
EOL

# Crear el servicio ProductoService con el namespace correcto
mkdir -p Services
cat <<EOL > Services/ProductoService.cs
using Microsoft.Data.SqlClient;
using System.Collections.Generic;
using System.Threading.Tasks;
using $PROJECT_NAME.Models;

namespace $PROJECT_NAME.Services
{
    public class ProductoService
    {
        private readonly string _connectionString;

        public ProductoService(string connectionString)
        {
            _connectionString = connectionString;
        }

        public async Task<List<Producto>> GetProductosAsync()
        {
            var productos = new List<Producto>();

            using (SqlConnection connection = new SqlConnection(_connectionString))
            {
                await connection.OpenAsync();
                string query = "SELECT ProductID, Name, ProductNumber, Color, StandardCost FROM Production.Product";

                using (SqlCommand command = new SqlCommand(query, connection))
                using (SqlDataReader reader = await command.ExecuteReaderAsync())
                {
                    while (await reader.ReadAsync())
                    {
                        productos.Add(new Producto
                        {
                            ProductID = reader.GetInt32(0),
                            Name = reader.GetString(1),
                            ProductNumber = reader.GetString(2),
                            Color = reader.IsDBNull(3) ? "N/A" : reader.GetString(3),
                            StandardCost = reader.GetDecimal(4)
                        });
                    }
                }
            }

            return productos;
        }
    }
}
EOL

# Crear el controlador ProductosController con el namespace correcto
mkdir -p Controllers
cat <<EOL > Controllers/ProductosController.cs
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;
using System.Threading.Tasks;
using $PROJECT_NAME.Models;
using $PROJECT_NAME.Services;

namespace $PROJECT_NAME.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ProductosController : ControllerBase
    {
        private readonly ProductoService _productoService;

        public ProductosController(ProductoService productoService)
        {
            _productoService = productoService;
        }

        [HttpGet]
        public async Task<ActionResult<List<Producto>>> Get()
        {
            var productos = await _productoService.GetProductosAsync();
            return Ok(productos);
        }
    }
}
EOL

# Crear Program.cs con la configuración del servicio y la cadena de conexión
cat <<EOL > Program.cs
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using $PROJECT_NAME.Services;

var builder = WebApplication.CreateBuilder(args);

string connectionString = "$DB_CONNECTION_STRING";

builder.Services.AddSingleton(new ProductoService(connectionString));
builder.Services.AddControllers();

var app = builder.Build();

app.UseAuthorization();
app.MapControllers();
app.Run();
EOL

# Crear el archivo de proyecto .csproj
cat <<EOL > $PROJECT_NAME.csproj
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.Data.SqlClient" Version="5.1.0" />
  </ItemGroup>
</Project>
EOL

# Crear Dockerfile para construir y ejecutar el proyecto en el contenedor
cat <<EOL > Dockerfile
# Usa la imagen de .NET SDK para compilar y ejecutar la aplicación
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish "$PROJECT_NAME.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "$PROJECT_NAME.dll", "--urls", "http://0.0.0.0:80"]
EOL

# Construir y ejecutar el contenedor Docker
docker build -t $CONTAINER_NAME .
docker run -d -p 5000:80 --name $CONTAINER_NAME $CONTAINER_NAME

echo "La API está corriendo en http://localhost:5000/api/productos"
