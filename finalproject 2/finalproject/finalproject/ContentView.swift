import SwiftUI
import Combine
import FirebaseAuth
import FirebaseDatabase

struct Exam: Identifiable {
    let id: String
    let testName: String
    let testDate: String
    let hourNeededForLearning: Double
    let breakIntervals: Int
    
    var remainingDays: Int {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd" // Updated date format
        guard let currentDate = dateFormatter.date(from: dateFormatter.string(from: Date())),
              let examDate = dateFormatter.date(from: testDate) else {
            return 0
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: currentDate, to: examDate)
        return components.day ?? 0
    }
    
    var numIntervalsPerDay: Double {
        let intervalMinutes = Double(breakIntervals) * 60.0
        return 60.0 * 10.0 / (intervalMinutes + 10.0)
    }
    
    var hoursToLearnForFirstExam: Int {
        let hours = numIntervalsPerDay * Double(breakIntervals)
        print("hoursToLearnForFirstExam: \(hours)")
        return Int(hours)
    }
    
    var hoursToLearnForNextExam: Int {
        let totalHoursForLearningADay = 10 // Assuming each day has 10 available studying hours
        let hoursLearnedForFirstExam = hoursToLearnForFirstExam
        let interval2 = (breakIntervals) + 1
        print("hoursToLearnForSecondExam: \(Int((totalHoursForLearningADay - hoursLearnedForFirstExam) * interval2))")
        return Int((totalHoursForLearningADay - hoursLearnedForFirstExam) * interval2)
    }
    
    var isEnoughTime: Bool {
        let totalAvailableHours = Double(remainingDays) * 10.0 // Assuming each day has 10 available studying hours
        return totalAvailableHours >= hourNeededForLearning
    }
}

class AppViewModel: ObservableObject {
    let auth = Auth.auth()
    let database = Database.database().reference()
    @Published var isSignedIn = false
    @Published var exams: [Exam] = []
    
    var isUserSignedIn: Bool {
        return auth.currentUser != nil
    }
    
    func signIn(email: String, password: String) {
        auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            guard result != nil, error == nil else {
                return
            }
            DispatchQueue.main.async {
                self?.isSignedIn = true
            }
        }
    }
    
    func signUp(email: String, password: String) {
        auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            guard result != nil, error == nil else {
                return
            }
            DispatchQueue.main.async {
                self?.isSignedIn = true
            }
        }
    }
    
    func fetchExams() {
        guard let currentUser = auth.currentUser else {
            print("No logged-in user")
            return
        }
        
        let userID = currentUser.uid
        let examsRef = database.child(userID).child("exams")
        
        examsRef.observe(.value) { [weak self] snapshot in
            var exams: [Exam] = []
            
            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot,
                   let examData = snapshot.value as? [String: Any],
                   let testName = examData["testName"] as? String,
                   let testDate = examData["testDate"] as? String,
                   let hourNeededForLearning = examData["hourNeededForLearning"] as? Double,
                   let breakIntervals = examData["breakIntervals"] as? Int {
                    let exam = Exam(id: snapshot.key,
                                    testName: testName,
                                    testDate: testDate,
                                    hourNeededForLearning: hourNeededForLearning,
                                    breakIntervals: breakIntervals)
                    exams.append(exam)
                }
            }
            
            DispatchQueue.main.async {
                self?.exams = exams
            }
        }
    }
}

struct ContentView: View {
    @State private var isSignUpActive = false
    @StateObject private var viewModel = AppViewModel() // Use @StateObject for proper lifecycle management
    
    var body: some View {
        NavigationView {
            Group {
                if isSignUpActive {
                    SignUpView(onSignUp: { isSignUpActive = false })
                        .environmentObject(viewModel) // Provide the environment object to SignUpView
                } else if viewModel.isSignedIn {
                    HomePage()
                        .environmentObject(viewModel) // Provide the environment object to HomePage
                } else {
                    LoginView(onLogin: { viewModel.isSignedIn = true }, onSignUp: { isSignUpActive = true })
                        .environmentObject(viewModel) // Provide the environment object to LoginView
                }
            }
        }
        .environmentObject(viewModel) // Provide the environment object to ContentView
    }
}

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @EnvironmentObject var viewModel: AppViewModel
    
    let onLogin: () -> Void
    let onSignUp: () -> Void
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.86, green: 0.23, blue: 0.55), Color(red: 0.91, green: 0.36, blue: 0.44), Color(red: 0.95, green: 0.5, blue: 0.34), Color(red: 0.98, green: 0.7, blue: 0.27), Color(red: 1, green: 0.87, blue: 0.25)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack {
                Image("instagram_logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 60)
                
                Text("Log in to your account")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: {
                    guard !email.isEmpty, !password.isEmpty else {
                        return
                    }
                    viewModel.signIn(email: email, password: password)
                }) {
                    Text("Login")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
                
                Button(action: {
                    onSignUp()
                }) {
                    Text("Don't have an account yet?")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .underline()
                        .padding(.bottom)
                }
            }
            .padding()
        }
    }
}

struct SignUpView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @EnvironmentObject var viewModel: AppViewModel
    let onSignUp: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.86, green: 0.23, blue: 0.55), Color(red: 0.91, green: 0.36, blue: 0.44), Color(red: 0.95, green: 0.5, blue: 0.34), Color(red: 0.98, green: 0.7, blue: 0.27), Color(red: 1, green: 0.87, blue: 0.25)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack {
                Text("Sign Up")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: {
                    guard !email.isEmpty, !password.isEmpty else {
                        return
                    }
                    viewModel.signUp(email: email, password: password)
                    presentationMode.wrappedValue.dismiss()
                    onSignUp() // Call the onSignUp closure to move to the LoginView page
                }) {
                    Text("Sign Up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
            }
            .padding()
        }
    }
}
struct HomePage: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showFavoriteView = false
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.7, green: 0.85, blue: 1.0), Color(red: 1.0, green: 1.0, blue: 0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            ScrollView {
                VStack {
                    Text("Date: \(dateFormatter.string(from: Date()))")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                    
                    Text("Upcoming tests:")
                        .font(.headline)
                        .padding(.bottom, 20)
                    
                    if let exams = upcomingExams()?.prefix(2) {
                        if exams.isEmpty {
                            Text("No upcoming exams within the next month.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 20)
                        } else {
                            ForEach(exams) { exam in
                                if exam.isEnoughTime {
                                    if exam.hoursToLearnForNextExam > 0 {
                                        Text("Today, you need to learn \(exam.hoursToLearnForNextExam) hours for the \(exam.testName) exam.")
                                            .font(.subheadline)
                                            .padding(.bottom, 20)
                                    } else {
                                        Text("No study intervals required today for the \(exam.testName) exam.")
                                            .font(.subheadline)
                                            .padding(.bottom, 20)
                                    }
                                } else {
                                    Text("Not enough time to study for the \(exam.testName) exam.")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                        .padding(.bottom, 20)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.bottom, 60)
        .navigationBarHidden(true)
        .background(Color.white)
        .overlay(BottomMenuView(showFavoriteView: $showFavoriteView), alignment: .bottom)
        .sheet(isPresented: $showFavoriteView) {
            FavoriteView()
                .environmentObject(viewModel)
        }
        .onAppear {
            viewModel.fetchExams()
        }
    }
    
    func upcomingExams() -> [Exam]? {
        let currentDate = Date()
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentDate)!
        
        let filteredExams = viewModel.exams.filter { exam in
            if let examDate = dateFormatter.date(from: exam.testDate) {
                return currentDate...nextMonth ~= examDate
            }
            return false
        }
        
        let sortedExams = filteredExams.sorted { exam1, exam2 in
            if let date1 = dateFormatter.date(from: exam1.testDate), let date2 = dateFormatter.date(from: exam2.testDate) {
                return date1 < date2
            }
            return false
        }
        
        return sortedExams
    }
}

struct BottomMenuView: View {
    @Binding var showFavoriteView: Bool
    
    var body: some View {
        HStack {
            Spacer()
            
            NavigationLink(destination: NewExamView()) {
                Image(systemName: "plus.square.on.square")
                    .font(.system(size: 25))
                //.foregroundColor(Color.pink)
                    .padding()
            }
            
            Spacer()
            
            Button(action: {
                showFavoriteView = true
            }) {
                Image(systemName: "heart")
                    .font(.system(size: 25))
                //.foregroundColor(Color.pink)
                    .padding()
            }
            Spacer()
            
            NavigationLink(destination: InspirationView()) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 25))
                // .foregroundColor(Color.pink)
                    .padding()
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        
        .background(Color(red: 1.0, green: 1.0, blue: 0.8))
    }
           

}
struct NewExamView: View {
    @State private var testName: String = ""
    @State private var testDate: Date = Date()
    @State private var hourNeededForLearning: Double = 0
    @State private var breakIntervals: Int = 0
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack{
            
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.7, green: 0.85, blue: 1.0), Color(red: 1.0, green: 1.0, blue: 0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack {
                TextField("Test Name", text: $testName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                DatePicker("Test Date", selection: $testDate, displayedComponents: .date)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                    .padding()
                
                Stepper(value: $hourNeededForLearning, in: 0...24, step: 1) {
                    Text("Hour Needed For Learning: \(hourNeededForLearning, specifier: "%.0f")")
                }
                .padding()
                
                Stepper(value: $breakIntervals, in: 0...5, step: 1) {
                    Text("Break Intervals: \(breakIntervals)")
                }
                .padding()
                
                Button(action: {
                    saveExam()
                    presentationMode.wrappedValue.dismiss() // Dismiss the current view and go back to the previous view (HomePage)
                }) {
                    Text("Save Exam")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
                
                Spacer()
            }
            .padding()
            .navigationBarTitle("New Exam")
        }
    }
    
    func saveExam() {
        guard let currentUser = Auth.auth().currentUser else {
            print("No logged-in user")
            return
        }
        
        let userID = currentUser.uid
        let ref = Database.database().reference().child(userID).child("exams").childByAutoId()
        
        let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }()
        
        let examData: [String: Any] = [
            "testName": testName,
            "testDate": dateFormatter.string(from: testDate),
            "hourNeededForLearning": hourNeededForLearning,
            "breakIntervals": breakIntervals
        ]
        
        ref.setValue(examData) { error, _ in
            if let error = error {
                print("Failed to save exam: \(error.localizedDescription)")
            } else {
                print("Exam saved successfully!")
            }
        }
    }
}
struct FavoriteView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedExam: Exam?
    
    var sortedExams: [Exam] {
        viewModel.exams.sorted { exam1, exam2 in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            if let date1 = dateFormatter.date(from: exam1.testDate),
               let date2 = dateFormatter.date(from: exam2.testDate) {
                return date1 < date2
            }
            
            return false
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.7, green: 0.85, blue: 1.0), Color(red: 1.0, green: 1.0, blue: 0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack {
                Text("Favorite Exams")
                    .font(.title)
                    .padding()
                
                List {
                    ForEach(sortedExams) { exam in
                        VStack(alignment: .leading) {
                            Text(exam.testName)
                                .font(.headline)
                            Text("Date: \(exam.testDate)")
                                .font(.subheadline)
                            Text("Hours Needed: \(Int(exam.hourNeededForLearning))")
                                .font(.subheadline)
                            Text("Break Intervals: \(exam.breakIntervals)")
                                .font(.subheadline)
                        }
                        .contextMenu {
                            Button(action: {
                                deleteExam(exam)
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .onTapGesture {
                            selectedExam = exam
                        }
                        .actionSheet(item: $selectedExam) { exam in
                            ActionSheet(title: Text("Delete Exam"),
                                        message: Text("Are you sure you want to delete this exam?"),
                                        buttons: [
                                            .destructive(Text("Delete"), action: {
                                                deleteExam(exam)
                                            }),
                                            .cancel()
                                        ]
                            )
                        }
                    }
                }
            }
            .padding()
            .navigationBarTitle("Favorite Exams")
        }
        .onAppear {
            viewModel.fetchExams()
        }
    }
    
    func deleteExam(_ exam: Exam) {
        guard let currentUser = Auth.auth().currentUser else {
            print("No logged-in user")
            return
        }
        
        let userID = currentUser.uid
        let examRef = Database.database().reference().child(userID).child("exams").child(exam.id)
        
        examRef.removeValue { error, _ in
            if let error = error {
                print("Failed to delete exam: \(error.localizedDescription)")
            } else {
                print("Exam deleted successfully!")
            }
        }
        
        if let index = viewModel.exams.firstIndex(where: { $0.id == exam.id }) {
            viewModel.exams.remove(at: index)
        }
    }
}

struct InspirationView: View {
    let quotes = [
        "Success is not the key to happiness. Happiness is the key to success. If you love what you are doing, you will be successful.",
        "The future belongs to those who believe in the beauty of their dreams.",
        "Believe you can and you're halfway there.",
        "The only way to do great work is to love what you do.",
        "The best way to predict your future is to create it.",
        "The only limit to our realization of tomorrow will be our doubts of today.",
        "Don't watch the clock; do what it does. Keep going.",
        "You are never too old to set another goal or to dream a new dream.",
        "Success is not in what you have, but who you are.",
        "Your time is limited, don't waste it living someone else's life.",
        "The harder you work for something, the greater you'll feel when you achieve it."
    ]
    
    @State private var randomQuote: String = ""
    
    var body: some View {
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    
                    Text(randomQuote)
                        .font(Font.custom("Noteworthy", size: 20))
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(width: geometry.size.width ) // Adjust the frame width to your preference
                    
                    Spacer()
                }
            }
            .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.86, green: 0.23, blue: 0.55), Color(red: 0.91, green: 0.36, blue: 0.44), Color(red: 0.95, green: 0.5, blue: 0.34), Color(red: 0.98, green: 0.7, blue: 0.27), Color(red: 1, green: 0.87, blue: 0.25)]), startPoint: .topLeading, endPoint: .bottomTrailing))
            .ignoresSafeArea()
            .foregroundColor(.white)
            .onAppear {
                randomQuote = getRandomQuote()
            }
        }
    
    func getRandomQuote() -> String {
        let randomIndex = Int.random(in: 0..<quotes.count)
        return quotes[randomIndex]
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
