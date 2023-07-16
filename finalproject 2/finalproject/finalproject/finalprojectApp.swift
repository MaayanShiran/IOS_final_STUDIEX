import SwiftUI
import Firebase
import FirebaseDatabase

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        return true
    }
}




@main
struct finalprojectApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var viewModel = AppViewModel()
    

    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
                    .environmentObject(viewModel)
                  //  .onAppear {
                        //saveDataToRealtimeDatabase()
                    //}
            }
        }
    }
   /*
    func saveDataToRealtimeDatabase() {
        let database = Database.database().reference()
        let usersRef = database.child("users")
        let userID = "userID"
        
        let name = "John Doe"
        let age = 30
        
        let userRef = usersRef.child(userID)
        userRef.setValue([
            "name": name,
            "age": age
        ]) { (error, ref) in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            } else {
                print("Data returned to Realtime Database successfully")
            }
        }
    }
    */
   
}
