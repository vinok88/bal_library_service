import ballerina/io;
import ballerinax/java.jdbc;

# Prints `Hello World`.

public function main() {
    createTable();
}

jdbc:Client libryDB = new({
    url:"jdbc:mysql://localhost:3306/libdb1",
    username:"root",
    password:"root",
    dbOptions: { useSSL: false }
    });

function createTable() {
    var result = libryDB->update("CREATE TABLE library(name VARCHAR(255), count INT, PRIMARY KEY (name))");
    if (result is jdbc:UpdateResult) {
        io:println("Table created successfully.");
    } else {
        error e = result;
        io:println("Table creation failed:", <string>e.detail()["message"]);
    }
}
