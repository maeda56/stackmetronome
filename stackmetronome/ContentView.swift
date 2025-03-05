import SwiftUI
import AVFoundation

// MARK: - Models

struct TempoStack: Identifiable, Codable {
    var id = UUID()
    var name: String
    var items: [TempoItem]
    
    static let sample = TempoStack(name: "ウォーミングアップ", items: [
        TempoItem(bpm: 100, beats: 16),
        TempoItem(bpm: 110, beats: 16),
        TempoItem(bpm: 120, beats: 16),
        TempoItem(bpm: 130, beats: 16),
        TempoItem(bpm: 140, beats: 16),
        TempoItem(bpm: 150, beats: 16),
        TempoItem(bpm: 160, beats: 16)
    ])
}

struct TempoItem: Identifiable, Codable {
    var id = UUID()
    var bpm: Int
    var beats: Int
    var timeSignature: TimeSignature = .fourFour
    
    var durationInSeconds: Double {
        let beatsPerSecond = Double(bpm) / 60.0
        return Double(beats) / beatsPerSecond
    }
    
    var measures: Int {
        return beats / timeSignature.beatsPerMeasure
    }
}

enum TimeSignature: String, Codable, CaseIterable {
    case twoFour = "2/4"
    case threeFour = "3/4"
    case fourFour = "4/4"
    case fiveFour = "5/4"
    case sixEight = "6/8"
    
    var beatsPerMeasure: Int {
        switch self {
        case .twoFour: return 2
        case .threeFour: return 3
        case .fourFour: return 4
        case .fiveFour: return 5
        case .sixEight: return 6
        }
    }
}

// MARK: - View Models

class MetronomeEngine: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var tickSound: URL?
    private var accentSound: URL?
    
    @Published var currentStack: TempoStack?
    @Published var isPlaying = false
    @Published var currentTempoIndex = 0
    @Published var currentBeat = 0
    @Published var remainingBeats = 0
    
    // 現在の小節数を計算
    var currentMeasure: Int {
        guard let stack = currentStack, currentTempoIndex < stack.items.count else { return 0 }
        let timeSignature = stack.items[currentTempoIndex].timeSignature
        return currentBeat / timeSignature.beatsPerMeasure
    }
    
    // 残りの小節数を計算
    var remainingMeasures: Int {
        guard let stack = currentStack, currentTempoIndex < stack.items.count else { return 0 }
        let timeSignature = stack.items[currentTempoIndex].timeSignature
        return remainingBeats / timeSignature.beatsPerMeasure
    }
    
    init() {
        // Load sound files
        if let tickURL = Bundle.main.url(forResource: "tick", withExtension: "wav") {
            self.tickSound = tickURL
        }
        
        if let accentURL = Bundle.main.url(forResource: "accent", withExtension: "wav") {
            self.accentSound = accentURL
        }
    }
    
    func playSound(isAccent: Bool) {
        let soundURL = isAccent ? accentSound : tickSound
        
        guard let url = soundURL else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Failed to play sound: \(error)")
        }
    }
    
    func startMetronome(stack: TempoStack) {
        guard !stack.items.isEmpty else { return }
        
        self.currentStack = stack
        self.isPlaying = true
        self.currentTempoIndex = 0
        self.currentBeat = 0
        
        startCurrentTempo()
    }
    
    func startCurrentTempo() {
        guard let stack = currentStack, currentTempoIndex < stack.items.count else {
            stopMetronome()
            return
        }
        
        let currentItem = stack.items[currentTempoIndex]
        self.remainingBeats = currentItem.beats
        
        let interval = 60.0 / Double(currentItem.bpm)
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    func tick() {
        guard let stack = currentStack, currentTempoIndex < stack.items.count else {
            stopMetronome()
            return
        }
        
        let currentItem = stack.items[currentTempoIndex]
        let timeSignature = currentItem.timeSignature
        
        // Play accent on first beat of measure
        let isFirstBeatOfMeasure = currentBeat % timeSignature.beatsPerMeasure == 0
        playSound(isAccent: isFirstBeatOfMeasure)
        
        currentBeat += 1
        remainingBeats -= 1
        
        // Move to next tempo when finished with current tempo
        if remainingBeats <= 0 {
            currentTempoIndex += 1
            currentBeat = 0
            
            if currentTempoIndex < stack.items.count {
                startCurrentTempo()
            } else {
                stopMetronome()
            }
        }
    }
    
    func stopMetronome() {
        timer?.invalidate()
        timer = nil
        isPlaying = false
        currentBeat = 0
        remainingBeats = 0
    }
    
    func pauseMetronome() {
        timer?.invalidate()
        timer = nil
        isPlaying = false
    }
    
    func resumeMetronome() {
        guard let stack = currentStack, currentTempoIndex < stack.items.count else {
            return
        }
        
        isPlaying = true
        startCurrentTempo()
    }
}

class StackStore: ObservableObject {
    @Published var stacks: [TempoStack] = [] {
        didSet {
            save()
        }
    }
    
    init() {
        loadStacks()
    }
    
    func loadStacks() {
        guard let data = UserDefaults.standard.data(forKey: "tempo_stacks") else {
            // Load sample data if no saved data
            self.stacks = [TempoStack.sample]
            return
        }
        
        do {
            let decoder = JSONDecoder()
            self.stacks = try decoder.decode([TempoStack].self, from: data)
        } catch {
            print("Failed to load stacks: \(error)")
            self.stacks = [TempoStack.sample]
        }
    }
    
    func save() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(stacks)
            UserDefaults.standard.set(data, forKey: "tempo_stacks")
        } catch {
            print("Failed to save stacks: \(error)")
        }
    }
    
    func addStack(stack: TempoStack) {
        stacks.append(stack)
    }
    
    func deleteStack(at offsets: IndexSet) {
        stacks.remove(atOffsets: offsets)
    }
    
    func moveStack(from source: IndexSet, to destination: Int) {
        stacks.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - Custom UI Components

struct ClayButton<Content: View>: View {
    var action: () -> Void
    var content: Content
    var color: Color
    var disabled: Bool
    
    init(action: @escaping () -> Void, color: Color = .blue, disabled: Bool = false, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
        self.color = color
        self.disabled = disabled
    }
    
    var body: some View {
        Button(action: action) {
            content
                .padding()
                .frame(minWidth: 44, minHeight: 44)
                .background(
                    Group {
                        if disabled {
                            color.opacity(0.3)
                        } else {
                            color
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: disabled ? .clear : color.opacity(0.3), radius: 5, x: 5, y: 5)
                .shadow(color: disabled ? .clear : .white.opacity(0.5), radius: 5, x: -5, y: -5)
        }
        .disabled(disabled)
    }
}

struct ClayCard<Content: View>: View {
    var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 8, y: 8)
                    .shadow(color: Color.white.opacity(0.7), radius: 10, x: -8, y: -8)
            )
            .padding()
    }
}

// MARK: - Views

struct ContentView: View {
    @EnvironmentObject var stackStore: StackStore
    @EnvironmentObject var metronomeEngine: MetronomeEngine
    
    var body: some View {
        TabView {
            StackListView()
                .environmentObject(stackStore)
                .environmentObject(metronomeEngine)
                .tabItem {
                    Label("スタック", systemImage: "square.stack.3d.up")
                }
            
            PlayerView()
                .environmentObject(stackStore)
                .environmentObject(metronomeEngine)
                .tabItem {
                    Label("プレイヤー", systemImage: "play.circle")
                }
        }
        .accentColor(Color.pink)
        .environmentObject(stackStore)
        .environmentObject(metronomeEngine)
    }
}

struct StackListView: View {
    @EnvironmentObject var stackStore: StackStore
    @EnvironmentObject var metronomeEngine: MetronomeEngine
    @State private var showingAddStack = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                List {
                    ForEach(stackStore.stacks) { stack in
                        NavigationLink(destination: StackDetailView(stack: stack)
                            .environmentObject(stackStore)
                            .environmentObject(metronomeEngine)) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(stack.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text("\(stack.items.count) テンポ")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if let firstItem = stack.items.first, let lastItem = stack.items.last {
                                        Text("\(firstItem.bpm)→\(lastItem.bpm) BPM")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .onDelete(perform: stackStore.deleteStack)
                    .onMove(perform: stackStore.moveStack)
                }
                .listStyle(InsetGroupedListStyle())
                .navigationTitle("Stack Metronome")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingAddStack = true }) {
                            Image(systemName: "plus")
                                .font(.headline)
                                .foregroundColor(.pink)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                            .foregroundColor(.pink)
                    }
                }
                .sheet(isPresented: $showingAddStack) {
                    AddStackView()
                        .environmentObject(stackStore)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct AddStackView: View {
    @EnvironmentObject var stackStore: StackStore
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var tempoItems = [TempoItem(bpm: 100, beats: 16)]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                Form {
                    Section(header: Text("スタック名")) {
                        TextField("名前", text: $name)
                            .font(.headline)
                            .padding(.vertical, 8)
                    }
                    
                    Section(header: Text("テンポ")) {
                        ForEach(0..<tempoItems.count, id: \.self) { index in
                            VStack {
                                HStack {
                                    Text("BPM")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 40)
                                    
                                    Stepper(value: Binding(
                                        get: { self.tempoItems[index].bpm },
                                        set: { self.tempoItems[index].bpm = $0 }
                                    ), in: 30...300) {
                                        Text("\(tempoItems[index].bpm)")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.pink)
                                            .frame(width: 60, alignment: .center)
                                    }
                                }
                                .padding(.vertical, 4)
                                
                                HStack {
                                    Text("拍数")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 40)
                                    
                                    Stepper(value: Binding(
                                        get: { self.tempoItems[index].beats },
                                        set: { self.tempoItems[index].beats = $0 }
                                    ), in: 1...64, step: 4) {
                                        Text("\(tempoItems[index].beats)")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.pink)
                                            .frame(width: 60, alignment: .center)
                                    }
                                }
                                .padding(.vertical, 4)
                                
                                HStack {
                                    Text("拍子")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 40)
                                    
                                    Picker("", selection: Binding(
                                        get: { self.tempoItems[index].timeSignature },
                                        set: { self.tempoItems[index].timeSignature = $0 }
                                    )) {
                                        ForEach(TimeSignature.allCases, id: \.self) { signature in
                                            Text(signature.rawValue).tag(signature)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .colorMultiply(.pink)
                                }
                                .padding(.vertical, 4)
                            }
                            .padding(.vertical, 8)
                        }
                        .onDelete(perform: deleteItem)
                        
                        Button(action: addItem) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.pink)
                                Text("テンポを追加")
                                    .foregroundColor(.pink)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                        }
                    }
                }
                .navigationTitle("新しいスタック")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("キャンセル") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(.pink)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("保存") {
                            let newStack = TempoStack(name: name.isEmpty ? "新しいスタック" : name, items: tempoItems)
                            stackStore.addStack(stack: newStack)
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(.pink)
                        .fontWeight(.bold)
                    }
                }
            }
        }
    }
    
    func addItem() {
        let lastBpm = tempoItems.last?.bpm ?? 100
        let newItem = TempoItem(bpm: lastBpm + 10, beats: 16)
        tempoItems.append(newItem)
    }
    
    func deleteItem(at offsets: IndexSet) {
        tempoItems.remove(atOffsets: offsets)
    }
}

struct StackDetailView: View {
    @EnvironmentObject var stackStore: StackStore
    @EnvironmentObject var metronomeEngine: MetronomeEngine
    
    var stack: TempoStack
    
    var stackIndex: Int? {
        stackStore.stacks.firstIndex(where: { $0.id == stack.id })
    }
    
    var body: some View {
        ZStack {
            // Background color
            Color(.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                List {
                    Section(header: Text("テンポ").font(.headline)) {
                        ForEach(stack.items) { item in
                            ClayCard {
                                VStack(alignment: .center, spacing: 12) {
                                    Text("\(item.bpm) BPM")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.pink)
                                    
                                    Divider()
                                    
                                    HStack(spacing: 20) {
                                        VStack {
                                            Text("\(item.beats)")
                                                .font(.system(size: 22, weight: .semibold))
                                            Text("拍")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        VStack {
                                            Text("\(item.measures)")
                                                .font(.system(size: 22, weight: .semibold))
                                            Text("小節")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        VStack {
                                            Text(String(format: "%.1f", item.durationInSeconds))
                                                .font(.system(size: 22, weight: .semibold))
                                            Text("秒")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                    }
                    
                    Section {
                        ClayButton(action: {
                            metronomeEngine.startMetronome(stack: stack)
                        }, color: .pink) {
                            HStack {
                                Image(systemName: "play.fill")
                                    .font(.headline)
                                Text("このスタックを再生")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .navigationTitle(stack.name)
    }
}

struct PlayerView: View {
    @EnvironmentObject var metronomeEngine: MetronomeEngine
    @EnvironmentObject var stackStore: StackStore
    @State private var selectedStackID: UUID?
    
    var selectedStack: TempoStack? {
        guard let id = selectedStackID else { return nil }
        return stackStore.stacks.first(where: { $0.id == id })
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // Stack selector
                    ClayCard {
                        Picker("スタック選択", selection: $selectedStackID) {
                            Text("選択してください").tag(nil as UUID?)
                            ForEach(stackStore.stacks) { stack in
                                Text(stack.name).tag(stack.id as UUID?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .accentColor(.pink)
                    }
                    .padding(.top)
                    
                    // Current playing info
                    if metronomeEngine.isPlaying, let stack = metronomeEngine.currentStack, metronomeEngine.currentTempoIndex < stack.items.count {
                        let currentItem = stack.items[metronomeEngine.currentTempoIndex]
                        
                        ClayCard {
                            VStack(spacing: 30) {
                                Text("\(currentItem.bpm) BPM")
                                    .font(.system(size: 60, weight: .bold))
                                    .foregroundColor(.pink)
                                
                                VStack(spacing: 10) {
                                    Text("残り \(metronomeEngine.remainingMeasures) 小節")
                                        .font(.title2)
                                        .fontWeight(.medium)
                                    
                                    Text("スタック: \(stack.name)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Beat indicators
                                HStack(spacing: 12) {
                                    ForEach(0..<4, id: \.self) { i in
                                        Circle()
                                            .fill(i == metronomeEngine.currentBeat % 4 ? Color.pink : Color.gray.opacity(0.3))
                                            .frame(width: 20, height: 20)
                                            .shadow(color: i == metronomeEngine.currentBeat % 4 ? Color.pink.opacity(0.5) : Color.clear, radius: 5, x: 0, y: 0)
                                    }
                                }
                                
                                // Progress through current stack
                                if let stack = metronomeEngine.currentStack {
                                    VStack(spacing: 8) {
                                        ProgressView(value: Double(metronomeEngine.currentTempoIndex), total: Double(stack.items.count))
                                            .accentColor(.pink)
                                        
                                        Text("テンポ \(metronomeEngine.currentTempoIndex + 1) / \(stack.items.count)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        // Empty state
                        ClayCard {
                            VStack(spacing: 20) {
                                Image(systemName: "waveform.circle")
                                    .font(.system(size: 60))
                                    .foregroundColor(.pink.opacity(0.7))
                                
                                Text(selectedStack == nil ? "スタックを選択して再生してください" : "再生ボタンを押して開始")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(height: 300)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    
                    Spacer()
                    
                    // Controls
                    HStack(spacing: 40) {
                        ClayButton(action: {
                            if metronomeEngine.isPlaying {
                                metronomeEngine.stopMetronome()
                            } else if let stack = selectedStack {
                                metronomeEngine.startMetronome(stack: stack)
                            }
                        }, color: metronomeEngine.isPlaying ? .red : .pink, disabled: !metronomeEngine.isPlaying && selectedStack == nil) {
                            Image(systemName: metronomeEngine.isPlaying ? "stop.fill" : "play.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                        
                        ClayButton(action: {
                            if metronomeEngine.isPlaying {
                                metronomeEngine.pauseMetronome()
                            } else {
                                metronomeEngine.resumeMetronome()
                            }
                        }, color: .blue, disabled: !metronomeEngine.isPlaying && metronomeEngine.currentStack == nil) {
                            Image(systemName: metronomeEngine.isPlaying ? "pause.fill" : "play.resume")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .padding()
            }
            .navigationTitle("プレイヤー")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
