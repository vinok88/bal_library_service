import ballerina/http;
import ballerinax/java.jdbc;
listener http:Listener libEP = new(9090);

jdbc:Client libryDB = new({
    url:"jdbc:mysql://localhost:3306/libDB",
    username:"root",
    password:"root",
    dbOptions: { useSSL: false }
    });

type Book record {
            int? count;
            string? name;
        };

@http:ServiceConfig {
    basePath: "/lib"
}
service libService on libEP {
    @http:ResourceConfig {
        path: "/add/{book}"
    }
    resource function addBook(http:Caller caller, http:Request request, string book) {
        string addNewBook = "INSERT INTO library(name, count) values (?,?)";
    
        var addNewBookRes = libryDB->update(addNewBook, book, 1);
        if (addNewBookRes is error) {
            error e = addNewBookRes;
            var res = caller->respond("Adding new Book failed :"+ <string>e.detail()["message"]);
        } else {
            var res = caller->respond("New book, " + book + " now available for borrowing!");
        }
    }

    @http:ResourceConfig {
        path: "/borrow/{book}"
    }
    resource function borrowBook(http:Caller caller, http:Request request, string book) {
        string selectBook = "SELECT count FROM 'library' where 'name' =?";
        string updateCount = "UPDATE 'library' SET 'count' = ? WHERE name=?";
        var selectBookRes = libryDB->select(selectBook, Book, book);
        boolean available = false;
        int count = 0;
        if (selectBookRes is table<Book>) {
            Book b = <Book>selectBookRes.getNext();
            count = <int>b.count;
            if (count > 0) {
               var updateRes = libryDB->update(updateCount, count, book);
               if (updateRes is jdbc:UpdateResult) {
                   var res = caller->respond("Happy reading, " + <@untiant>book + "!");
               } else {
                   error e = updateRes;
                   var res = caller->respond("Error borrowing book, " + <string>e.detail()["message"]);
               }
            } else {
               var res = caller->respond("Sorry, " + <@untiant>book + ", not available."); 
            }
        }
        
    }

    @http:ResourceConfig {
        path: "/return/{book}"
    }
    resource function returnBook(http:Caller caller, http:Request request, string book) {
        string returnBook = "UPDATE 'library' SET 'count' = 'count' + 1 WHERE name=?";
        var returnRes = libryDB->update(returnBook, book);
        if (returnRes is jdbc:UpdateResult) {
            var res = caller->respond("Return accepted for book: " + <@untiant>book + ".");
        } else {
            error e = returnRes;
            var res = caller->respond("Error returnning book, " + <string>e.detail()["message"]);
        }
    }               
}
