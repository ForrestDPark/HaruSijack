// MARK: -- Description
/*
    Description: 각 지하철 역별 승,하차인원 에측 페이지
    Date : 2024.6.11
    Author : Shin  + pdg + pjh
    Dtail :
    Updates :
         - 2024.06.11 j.park :
            * 1. 버튼 구현
            * 2. flask 서버에서 하차인원 Json통신
         - 2024.06.12 j.park :
            * 1. 현재시간, 특정역 기준 하차인원 추가
         - 2024.06.13 snr : 
            출근시간대 설정 sheet 연결
         - 2024.06.13 j.park : 
            1.승차인원 추가
            2. actionsheet에서 sheet로 변경
         - 2024.06.14 j.park : 
            1.특정역에 대한 전체 승하차인원 그래프 구현
         - 2024.06.17 j.park : 
            1. 예측페이지 진입전 lotti를 활용한 대기화면 구현
         - 2024.06.23 jdpark : 
            1. 지하철 노선 정보 중 5호선 추가 struct 파일로 만들고 거기서 불러오게 함.
         - 2024.06.24 by j, d park :
            * 1. sheet(예측페이지) 분리
              2.
 */

//


import SwiftUI

struct PredictView03: View {
    
//    let imgWidth: CGFloat = 6189
//    let imgHeight: CGFloat = 4465
    var body: some View {
        VStack(content: {
            ZStack(content: {
                GeometryReader { geometry in
                    subwayImage()
                } // GR
            })//ZS
        }) // VS
    }
}

// MARK: 지하철 이미지
struct subwayImage : View {
    
    // MARK: Server request 변수
    @State var stationName: String = ""
    @State var stationLine: String = "5"
    
    @State private var showAlertForStation = false
    // 승차인원 JSON 받아오는 변수(승차)
    @State var serverResponseBoardingPerson: String = ""
    // 승차인원 JSON 받아오는 변수(하차)
    @State var serverResponseAlightingPerson: String = ""
    // 현재시간 열차의 승차인원 변수
    @State var boardingPersonValue: Double = 0.0
    // 현재시간 열차의 하차인원 변수
    @State var AlightingPersonValue: Double = 0.0
    // 현재 날짜 저장
    @State var showingcurrentdate = ""
    // 현재 시간 저장
    @State var showingcurrentTime = ""
    //차트 테스트
    // 승차인원 JSON 값을 dictionary로 변환 변수
    @State private var BoardingPersondictionary: [String: Double] = [:]
    //하차인원
    @State private var AlightinggPersondictionary: [String: Double] = [:]
    //로딩중 화면
    @State private var isLoading = false
    
    // MARK: 화면조작 변수
    @State var currentScale: CGFloat = 1.0
    @State var previousScale: CGFloat = 1.0
    @State var currentOffset = CGSize.zero
    @State var previousOffset = CGSize.zero
//    let line23 = SubwayList().totalStation
    let line23 = SubwayList().testStation
    let imgWidth = UIImage(named: "subwayMap")!.size.width
    let imgHeight = UIImage(named: "subwayMap")!.size.height
    
    
    
    var body: some View {
        Image("subwayMap")
            .resizable()
            .frame(
                width: imgWidth * self.currentScale,
                height: imgHeight * self.currentScale)
            .overlay( GeometryReader { geometry in
                ForEach(Array(line23.enumerated()), id: \.0) { index, station in
                    Button(action: {
                        isLoading = true
                        print("line5 station \(station.0)")
                        handleStationClick(stationName: station.0, stationLine: String(station.3))
                    }) {
                        Text(".\(index) \(station.0)")
                            .font(.system(size: 10))
                            .bold()
                            .frame(width: 20, height: 20)
                            .background(Color.yellow)
                    }
                    .position(  x: (station.2 * self.currentScale),
                                y: (station.1 * self.currentScale))
                }//button
            })// OverLay
            .edgesIgnoringSafeArea(.all)
            .aspectRatio(contentMode: .fit)
            .offset(x: self.currentOffset.width, y: self.currentOffset.height)
            .scaleEffect(max(self.currentScale, 1.0)) // the second question
            .gesture(DragGesture()
                .onChanged { value in
                    
                    let deltaX = value.translation.width - self.previousOffset.width
                    let deltaY = value.translation.height - self.previousOffset.height
                    self.previousOffset.width = value.translation.width
                    self.previousOffset.height = value.translation.height
                    
                    //                            let newOffsetWidth = self.currentOffset.width + deltaX / self.currentScale
                    
                    self.currentOffset.width = self.currentOffset.width + deltaX / self.currentScale
                    self.currentOffset.height = self.currentOffset.height + deltaY / self.currentScale
                }
                     
                .onEnded { value in self.previousOffset = CGSize.zero })
        
        
            .gesture(MagnificationGesture()
                .onChanged { value in
                    let delta = value / self.previousScale
                    self.previousScale = value
                    self.currentScale = self.currentScale * delta
                }
                .onEnded { value in self.previousScale = 1.0 }
            )
            .sheet(isPresented: $showAlertForStation) {
                SheetContentView(
                    isLoading: $isLoading,
                    stationName: $stationName,
                    showingcurrentTime: $showingcurrentTime,
                    boardingPersonValue: $boardingPersonValue,
                    AlightingPersonValue: $AlightingPersonValue,
                    BoardingPersondictionary: $BoardingPersondictionary,
                    AlightinggPersondictionary: $AlightinggPersondictionary
                )
        }//sheet
                
    }// View
    
    // MARK: Functions
    func handleStationClick(stationName: String, stationLine: String) {
        
        
        self.stationName = stationName
        self.stationLine = stationLine
        
        let (dateString, timeString) = getCurrentDateTime()
        showingcurrentTime =  timeString
        showingcurrentdate =  dateString
        
        //승차인원
        fetchDataFromServerBoarding(stationName: stationName, date: dateString, time: timeString, stationLine: stationLine) { responseString in
            self.serverResponseBoardingPerson = responseString
            self.boardingPersonValue = getValueForCurrentTime(jsonString: responseString, currentTime: timeString)
            // 받아온 JSON데이터를 dictionary로 변경
            if let dictionary = convertJSONStringToDictionary(responseString) {
                
                //현재시간에서 범위에 있는 값들을 임시저장하기위한 딕셔너리
                var tempBoardingPersondictionary: [String: Double] = [:]
                // 정렬해서 배열로 가져오기(index번호로 데이터 가져오기 위해서)
                let sortedKeys = dictionary.keys.sorted()
                
                //lowerBound: 현재시시간에서 -7값이 0보다 작으면 0으로 고정(-7한 이유:배차시작이5기 때문)
                //upperBound: 키값에 인덱스를 초과한 값 방지
                let lowerBound = max(0, Int(showingcurrentTime)! - 7)
                let upperBound = min(sortedKeys.count - 1, Int(showingcurrentTime)! - 3)
                //
                if lowerBound <= upperBound && sortedKeys.indices.contains(upperBound) {
                    for index in lowerBound...upperBound {
                        
                        let key = sortedKeys[index]
                        if let value = dictionary[key] {
                            tempBoardingPersondictionary[key] = value
                        }
                    }
                }
                //전역변수에 저장
                self.BoardingPersondictionary = tempBoardingPersondictionary
//                
            } else {
                print("인덱스 범위 오류")
            }
            showAlertForStation = true
        } // fetchDataFromServerBoarding
        
        //하차인원
        fetchDataFromServerAlighting(stationName: stationName, date: dateString, time: timeString, stationLine: stationLine) { responseString in
            self.serverResponseAlightingPerson = responseString
            self.AlightingPersonValue = getValueForCurrentTime(jsonString: responseString, currentTime: timeString)
            //            let alightingTime=showingcurrentTime
            if let dictionary = convertJSONStringToDictionary(responseString) {
                
                //현재시간에서 범위에 있는 값들을 임시저장하기위한 딕셔너리
                var tempAlightingPersondictionary: [String: Double] = [:]
                // 정렬해서 배열로 가져오기(index번호로 데이터 가져오기 위해서)
                let sortedKeys = dictionary.keys.sorted()
                
                //lowerBound: 현재시시간에서 -7값이 0보다 작으면 0으로 고정(-7한 이유:배차시작이5기 때문)
                //upperBound: 키값에 인덱스를 초과한 값 방지
                let lowerBound = max(0, Int(showingcurrentTime)! - 7)
                let upperBound = min(sortedKeys.count - 1, Int(showingcurrentTime)! - 3)
                
                if lowerBound <= upperBound && sortedKeys.indices.contains(upperBound) {
                    for index in lowerBound...upperBound {
                        
                        let key = sortedKeys[index]
                        if let value = dictionary[key] {
                            tempAlightingPersondictionary[key] = value
                        }
                    }
                }
                //전역변수에 저장
                self.AlightinggPersondictionary = tempAlightingPersondictionary
                
            } else {
                print("인덱스 범위에 해당하는 요소가 없습니다.")
            }
            showAlertForStation = true
        } //fetchDataFromServerAlighting
        
    } //handleStationClick

    // 현재시간 가져오는 함수
    func getCurrentDateTime() -> (String, String) {
        let currentDate = Date()
        
        // Date Formatter for Date
        let dateFormatterDate = DateFormatter()
        dateFormatterDate.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatterDate.string(from: currentDate)
        
        // Date Formatter for Time
        let dateFormatterTime = DateFormatter()
        dateFormatterTime.dateFormat = "HH"
        let timeString = String(Int(dateFormatterTime.string(from: currentDate))!)
        
        return (dateString, timeString)
    }
    
    // Flask 통신을 위한 함수(승차인원)
    func fetchDataFromServerBoarding(stationName: String, date: String, time: String, stationLine: String, completion: @escaping (String) -> Void) {
        let url = URL(string: "http://127.0.0.1:5000/subway")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let parameters: [String: Any] = [
            "stationName": stationName,
            "date": date,
            "time": time,
            "stationLine": stationLine
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error:", error ?? "Unknown error")
                return
            }
            if let responseString = String(data: data, encoding: .utf8) {
                completion(responseString)
            }
        }
        task.resume()
    }

    // Flask 통신을 위한 함수(하차인원)
    func fetchDataFromServerAlighting(stationName: String, date: String, time: String, stationLine: String, completion: @escaping (String) -> Void) {
        print(stationName,date,time,stationLine)
        let url = URL(string: "http://127.0.0.1:5000/subwayAlighting")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let parameters: [String: Any] = [
            "stationName": stationName,
            "date": date,
            "time": time,
            "stationLine": stationLine
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error:", error ?? "Unknown error")
                
                return
            }
            if let responseString = String(data: data, encoding: .utf8) {
                completion(responseString)
            }
        }
        task.resume()
    }

    // 현재시간에 "시인원"을 더한 값을 key값으로 서버에서 받아온 JSON값에서 검색해서 값을 가져오는 함수
    func getValueForCurrentTime(jsonString: String, currentTime: String) -> Double {
        guard let jsonData = jsonString.data(using: .utf8) else { return 0.0 }
        do {
            if let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                let keyForCurrentTime = "\(currentTime)시인원"
                if let value = json[keyForCurrentTime] as? Double {
                    return value
                }
            }
        } catch {
            print("Error parsing JSON:", error)
        }
        return 0.0
    }

    // JSON 데이터를 dictionary로 변환(차트그리기 위해서)
    func convertJSONStringToDictionary(_ jsonString: String) -> [String: Double]? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("딕셔너리 변환 실패.")
            return nil
        }
        
        do {
            let dictionary = try JSONDecoder().decode([String: Double].self, from: jsonData)
            return dictionary
        } catch {
            print("Error decoding JSON: \(error.localizedDescription)")
            return nil
        }
    }

}



// MARK: Preview


#Preview {
    PredictView03()
}
