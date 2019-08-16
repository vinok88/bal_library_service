import ballerina/http;
import ballerinax/java.jdbc;
import ballerina/cache;

listener http:Listener libEP = new(9090);

jdbc:Client libryDB = new({
    url:"jdbc:h2:~/libDB",
    username:"sa",
    password:"",
    dbOptions: { useSSL: false }
    });

type Book record {
            int count;
            string name;
        };
type Count record {
    int count;
};

cache:Cache cache = new(1000, 600000, 0.2);

@http:ServiceConfig {
    basePath: "/lib"
}
service libService on libEP {
    @http:ResourceConfig {
        path: "/add/{book}"
    }
    resource function addBook(http:Caller caller, http:Request request, string book) {
        lock {
            var bookCache = cache.get(book);
            if (bookCache is ()) {
                cache.put(book, 1);
            } else {
                cache.put(book, <int>bookCache + 1);
            }
        }

        var res = caller->respond("Book added successfully!");
    }

    function addBookDB(http:Caller caller, http:Request request, string book) {
        string addNewBook = "INSERT INTO library(name, count) values (?,1)";
    
        var addNewBookRes = libryDB->update(addNewBook, book);
        if (addNewBookRes is error) {
            error e = addNewBookRes;
            var res = caller->respond("Adding new Book failed :"+ <string>e.detail()["message"]);
        } else {
            var res = caller->respond("New book, " + <@untiant>book + " now available for borrowing!");
        }
    }

    @http:ResourceConfig {
        path: "/borrow/{book}"
    }
    resource function borrowBook(http:Caller caller, http:Request request, string book) {
        //lock {
            var res = cache.get(book);
            io:println(book);
            io:println(res);
            if (res is ()) {
                var respondRes = caller->respond("book not available");
            } else {
                if (<int>res > 0) {
                    cache.put(book, <int>res - 1);
                    var respondRes = caller->respond("book available, Happy reading!");
                } else {
                    var respondRes = caller->respond("All copies borrowed, check back later..");
                }
            }
        //}
        
    }

    function borrowBookUpdateDB(http:Caller caller, http:Request request, string book) {
        string selectBook = "SELECT count FROM library where name =?";
        string updateCount = "UPDATE library SET count = ? WHERE name=?";
        var selectBookRes = libryDB->select(selectBook, Count, book);
        boolean available = false;
        int count = 0;
        if (selectBookRes is table<Count>) {
            Count b = <Count>selectBookRes.getNext();
            count = <int>b.count;
            io:println(count);
            if (count > 0) {
               var updateRes = libryDB->update(updateCount, count, book);
               if (updateRes is jdbc:UpdateResult) {
                   var res = caller->respond("Happy reading, " + <@untiant>book + "!");
               } else {
                   io:println("error 1");
                   error e = updateRes;
                   var res = caller->respond("Error borrowing book, " + <string>e.detail()["message"]);
               }
            } else {
               var res = caller->respond("Sorry, " + <@untiant>book + ", not available."); 
            }
        } else if(selectBookRes is jdbc:ApplicationError) {
            var res = caller->respond("Error fetching book info" + <@untiant><string>selectBookRes.detail()["message"]);
        } else {
            var res = caller->respond("Error fetching book info" + <@untiant><string>selectBookRes.detail()["message"]);
        }
    }

    @http:ResourceConfig {
        path: "/return/{book}"
    }
    resource function returnBook(http:Caller caller, http:Request request, string book) {
        var res = cache.get(book);
        io:println(res);
        if(res is ()) {
            var respondRes = caller->respond("Invalid book return request");
        } else {
            cache.put(book, <int>res + 1);
            var respondRes = caller->respond("book available, Happy reading!");
        }
    }

    function returnBookDB(http:Caller caller, http:Request request, string book){
        string returnBook = "UPDATE library SET count = count + 1 WHERE name=?";
        var returnRes = libryDB->update(returnBook, book);
        if (returnRes is jdbc:UpdateResult) {
            var res = caller->respond("Return accepted for book: " + <@untiant>book + ".");
        } else {
            error e = returnRes;
            var res = caller->respond("Error returnning book, " + <string>e.detail()["message"]);
        }
    }               
}
