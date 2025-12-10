# Firebase Cloud Functions - 인앱결제 검증

이 디렉토리에는 Google Play 및 App Store 인앱결제를 서버측에서 검증하는 Firebase Cloud Functions가 포함되어 있습니다.

## 🚀 설정 방법

### 1. Firebase Functions 초기화

```bash
# Firebase CLI 설치 (아직 설치하지 않은 경우)
npm install -g firebase-tools

# Firebase 로그인
firebase login

# 프로젝트 초기화 (이미 완료된 경우 건너뛰기)
firebase init functions
```

### 2. Google Play Developer API 설정 (Android)

#### 2.1 Google Cloud Console에서 API 활성화

1. [Google Cloud Console](https://console.cloud.google.com/)에 접속
2. Firebase 프로젝트 선택
3. "APIs & Services" > "Library" 이동
4. "Google Play Android Developer API" 검색 및 활성화

#### 2.2 서비스 계정 생성

1. "APIs & Services" > "Credentials" 이동
2. "Create Credentials" > "Service Account" 선택
3. 서비스 계정 이름 입력 (예: "iap-verifier")
4. 역할 추가: "Service Account User"
5. "Create Key" 클릭 > JSON 형식 선택
6. 다운로드된 JSON 파일을 `functions/service-account-key.json`으로 저장

#### 2.3 Google Play Console 권한 설정

1. [Google Play Console](https://play.google.com/console/)에 접속
2. "설정" > "API 액세스" 이동
3. 생성한 서비스 계정 찾기
4. "권한 관리" 클릭
5. "재무 데이터" 권한 부여

### 3. App Store 설정 (iOS)

#### 3.1 Shared Secret 생성

1. [App Store Connect](https://appstoreconnect.apple.com/)에 접속
2. "My Apps" > 앱 선택
3. "App Information" 이동
4. "App-Specific Shared Secret" 생성
5. 생성된 secret을 복사

#### 3.2 Firebase Config에 저장

```bash
firebase functions:config:set appstore.shared_secret="YOUR_SHARED_SECRET"
```

### 4. 패키지 이름 설정

`functions/index.js` 파일에서 패키지 이름을 실제 앱의 패키지 이름으로 변경:

```javascript
const PACKAGE_NAME = 'com.yourcompany.angelsjackpot'; // 실제 패키지 이름으로 변경
```

### 5. 의존성 설치 및 배포

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

## 📱 Flutter 앱에서 사용하기

### Cloud Function 호출 예제

```dart
import 'package:cloud_functions/cloud_functions.dart';

Future<bool> verifyPurchaseWithServer(PurchaseDetails purchaseDetails) async {
  try {
    final functions = FirebaseFunctions.instance;
    
    if (Platform.isAndroid) {
      final result = await functions.httpsCallable('verifyPurchase').call({
        'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
        'productId': purchaseDetails.productID,
        'userId': FirebaseAuth.instance.currentUser?.uid,
      });
      
      return result.data['verified'] == true;
    } else if (Platform.isIOS) {
      final result = await functions.httpsCallable('verifyAppleReceipt').call({
        'receiptData': purchaseDetails.verificationData.serverVerificationData,
        'productId': purchaseDetails.productID,
        'userId': FirebaseAuth.instance.currentUser?.uid,
      });
      
      return result.data['verified'] == true;
    }
    
    return false;
  } catch (e) {
    debugPrint('Error verifying purchase with server: $e');
    return false;
  }
}
```

### pubspec.yaml에 추가

```yaml
dependencies:
  cloud_functions: ^4.5.0
```

## 🔒 보안 고려사항

1. **서비스 계정 키 보호**: `service-account-key.json` 파일을 절대 Git에 커밋하지 마세요
2. **환경 변수 사용**: 프로덕션에서는 Firebase Functions Config 또는 Secret Manager 사용
3. **사용자 인증**: 가능한 경우 Firebase Authentication과 통합하여 사용자 검증
4. **로깅**: 모든 검증 시도를 로깅하여 부정 사용 감지

## 📊 Firestore 데이터 구조

### purchases 컬렉션

```
purchases/{orderId}
  - productId: string
  - purchaseToken: string (Android) / transactionId: string (iOS)
  - purchaseTime: number
  - userId: string
  - verifiedAt: timestamp
  - platform: string ("android" | "ios")
```

### users 컬렉션

```
users/{userId}
  - purchases
    - remove_ads
      - purchased: boolean
      - orderId: string
      - purchaseTime: number
```

## 🧪 테스트

### 로컬 테스트

```bash
# Functions 에뮬레이터 실행
firebase emulators:start --only functions

# 테스트 요청
curl -X POST http://localhost:5001/YOUR_PROJECT_ID/us-central1/verifyPurchase \
  -H "Content-Type: application/json" \
  -d '{"purchaseToken":"test_token","productId":"remove_ads"}'
```

### 프로덕션 테스트

1. Google Play Console에서 테스트 계정 설정
2. 테스트 구매 진행
3. Cloud Functions 로그 확인: `firebase functions:log`

## 📝 문제 해결

### "Permission denied" 오류

- 서비스 계정에 올바른 권한이 있는지 확인
- Google Play Console에서 서비스 계정 권한 재확인

### "Invalid purchase token" 오류

- 구매 토큰이 올바른지 확인
- 패키지 이름이 정확한지 확인

### "Receipt validation failed" (iOS)

- Shared Secret이 올바른지 확인
- 샌드박스/프로덕션 환경 확인

## 📚 참고 자료

- [Google Play Developer API](https://developers.google.com/android-publisher)
- [App Store Server API](https://developer.apple.com/documentation/appstoreserverapi)
- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)
