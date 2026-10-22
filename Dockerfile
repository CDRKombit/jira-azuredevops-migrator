# Linux image for jira-export and wi-import.
# Build:  docker build -t jira-ado-migrator .
# Run:    see migration/README.md

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY src/WorkItemMigrator/ ./
RUN dotnet publish JiraExport/jira-export.csproj -c Release -o /app/export -p:PublishSingleFile=false \
 && dotnet publish WorkItemImport/wi-import.csproj -c Release -o /app/import -p:PublishSingleFile=false

FROM mcr.microsoft.com/dotnet/runtime:6.0
WORKDIR /workspace
COPY --from=build /app /app
COPY docker-entrypoint.sh /usr/local/bin/migrate
RUN sed -i 's/\r$//' /usr/local/bin/migrate && chmod +x /usr/local/bin/migrate
ENTRYPOINT ["migrate"]
CMD ["help"]
