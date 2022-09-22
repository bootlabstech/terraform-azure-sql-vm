#!/bin/bash

systemctl stop mssql-server
MSSQL_SA_PASSWORD=${sqlpassword} /opt/mssql/bin/mssql-conf set-sa-password

systemctl enable mssql-server
systemctl start mssql-server