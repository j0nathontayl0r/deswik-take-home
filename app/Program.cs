using System.Data.SqlClient;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/health", () => Results.Ok("ok"));

app.MapGet("/", async () =>
{
    var dbHost = Environment.GetEnvironmentVariable("DB_HOST") ?? "";
    var dbPort = Environment.GetEnvironmentVariable("DB_PORT") ?? "1433";
    var dbName = Environment.GetEnvironmentVariable("DB_NAME") ?? "deswikdb";
    var dbUser = Environment.GetEnvironmentVariable("DB_USER") ?? "appuser";
    var dbPassword = Environment.GetEnvironmentVariable("DB_PASSWORD") ?? "";

    var connectionString =
        $"Server={dbHost},{dbPort};Database={dbName};User Id={dbUser};Password={dbPassword};";

    try
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        return Results.Ok("Hello Deswik, we are connected to SQL Server");
    }
    catch (Exception ex)
    {
        return Results.Problem($"Database connection failed: {ex.Message}");
    }
});

app.Run();
