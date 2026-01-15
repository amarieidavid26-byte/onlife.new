# AI Insights Testing & Verification Plan

## ✅ Implementation Complete

### Files Modified:
1. **AnalyticsViewModel.swift** - Added `testAIInsight()` method
2. **AnalyticsView.swift** - Added DEBUG conditional for testing
3. **GeminiService.swift** - Environment variable API key management
4. **Config.xcconfig** - Created for API key storage
5. **.gitignore** - Added config file exclusions

---

## 🧪 Test Scenarios

### Test 1: Mock AI Insight (DEBUG Mode)
**Purpose**: Verify UI works without real API key

**Steps**:
1. Build project in DEBUG mode (default for simulator)
2. Launch app in iOS Simulator
3. Complete at least 3 focus sessions to unlock analytics
4. Navigate to "Insights" tab
5. Observe AI Insight Card

**Expected Behavior**:
- ✅ Card appears at top of Analytics view (below stats header)
- ✅ Loading spinner shows for ~1.5 seconds
- ✅ Yellow border (0.3 opacity) highlights the card
- ✅ "AI Insight" header with sparkles icon appears
- ✅ Mock insight displays: "You focus 45% longer in coffee shops - schedule deep work there! ☕"
- ✅ Card background uses `AppColors.lightSoil`
- ✅ Text is readable with proper spacing

**Current Status**: Ready to test

---

### Test 2: Loading State
**Purpose**: Verify loading indicator works

**Steps**:
1. Navigate to Analytics tab
2. Observe card during first 1.5 seconds

**Expected Behavior**:
- ✅ ProgressView spinner appears in top-right of card
- ✅ Spinner animates smoothly
- ✅ Card structure remains stable (no layout shifts)

**Current Status**: Ready to test

---

### Test 3: Less Than 5 Sessions
**Purpose**: Verify locked state message

**Steps**:
1. Ensure you have exactly 3-4 completed sessions
2. Navigate to Analytics tab
3. Wait for loading to complete

**Expected Behavior**:
- ✅ Message displays: "Complete 5+ sessions to unlock AI-powered insights!"
- ✅ No mock insight shown
- ✅ Card still has yellow border and proper styling

**Current Status**: Ready to test

---

### Test 4: Error State (Simulated)
**Purpose**: Verify fallback message works

**To Test**:
1. Temporarily modify `testAIInsight()` to set `aiInsightError = "Test error"`
2. Rebuild and run
3. Navigate to Analytics tab

**Expected Behavior**:
- ✅ Orange warning triangle icon appears
- ✅ Message: "Using pattern-based insights"
- ✅ Fallback insight from `generateFallbackInsight()` displays

**Current Status**: Requires code modification to test

---

### Test 5: Template Insights Still Work
**Purpose**: Ensure AI card doesn't break existing insights

**Steps**:
1. Navigate to Analytics tab
2. Scroll down below AI Insight Card

**Expected Behavior**:
- ✅ "Smart Insights" section still appears
- ✅ Template insights (streak, week growth, etc.) display correctly
- ✅ All analytics cards render properly

**Current Status**: Ready to test

---

### Test 6: Multiple Tab Switches
**Purpose**: Verify caching and state management

**Steps**:
1. Navigate to Analytics tab (insight loads)
2. Switch to "Gardens" tab
3. Switch back to "Analytics" tab
4. Repeat 3-4 times

**Expected Behavior**:
- ✅ Insight doesn't reload every time (uses cached value)
- ✅ No memory leaks or performance issues
- ✅ Loading state doesn't repeat unnecessarily

**Current Status**: Ready to test

---

### Test 7: Real API Integration (Future)
**Purpose**: Verify real Gemini API works

**Steps**:
1. Get API key from https://makersuite.google.com/app/apikey
2. Add to `Config.xcconfig`: `GEMINI_API_KEY = your_actual_key`
3. In Xcode: Product > Scheme > Edit Scheme > Run > Arguments > Environment Variables
4. Add: `GEMINI_API_KEY = $(GEMINI_API_KEY)`
5. Build in RELEASE mode or comment out `#if DEBUG` block
6. Run app and navigate to Analytics

**Expected Behavior**:
- ✅ Real API call made (may take 2-5 seconds)
- ✅ Personalized insight based on actual user data
- ✅ Insight cached for 1 hour
- ✅ Rate limiting prevents calls within 60 seconds

**Current Status**: Not yet configured (requires API key)

---

## 🐛 Known Issues / Edge Cases to Verify

1. **Empty State**: What happens if user has 0 sessions?
   - Expected: Analytics tab shows "No Analytics Yet" message
   - AI card should not appear

2. **Exactly 3 Sessions**: Boundary condition
   - Expected: Analytics visible, but AI locked state shows

3. **Network Errors** (with real API):
   - Expected: Falls back to template insight
   - Error message displayed

4. **Very Long Insight Text**:
   - Expected: Text wraps properly with `.lineLimit(nil)`
   - No text truncation

5. **Dark Mode** (if supported):
   - Expected: Colors adapt appropriately
   - Yellow border still visible

---

## 📊 Success Criteria

All tests pass if:
- ✅ No crashes or errors
- ✅ UI renders correctly in all states
- ✅ Loading states smooth and informative
- ✅ Text readable and properly formatted
- ✅ Yellow border visible and aesthetically pleasing
- ✅ Mock insight displays in DEBUG mode
- ✅ Fallback insights work when API fails
- ✅ Performance acceptable (no lag)

---

## 🚀 Next Steps

1. **Manual Testing**: Run through Test 1-6 in simulator
2. **Screenshot Review**: Verify visual design matches expectations
3. **Performance Check**: Monitor memory/CPU usage
4. **API Key Setup**: When ready, configure real Gemini API key
5. **A/B Testing**: Compare mock vs. real insights for quality

---

## 📝 Test Results Log

| Test | Status | Notes | Date |
|------|--------|-------|------|
| Mock AI Insight | ⏳ Pending | - | - |
| Loading State | ⏳ Pending | - | - |
| <5 Sessions Lock | ⏳ Pending | - | - |
| Error State | ⏳ Pending | - | - |
| Template Insights | ⏳ Pending | - | - |
| Tab Switching | ⏳ Pending | - | - |
| Real API | ⏳ Not Started | Requires API key | - |

---

## 🔍 Debug Tips

**Print Statements**:
```swift
// In testAIInsight()
print("🧪 TEST: Starting mock AI insight generation")
print("🧪 TEST: Loading state set")
print("🧪 TEST: Mock insight displayed")

// In generateAIInsight()
print("🤖 AI: Starting real insight generation")
print("🤖 AI: Cache check - \(aiInsight != nil)")
print("🤖 AI: Calling Gemini API...")
```

**Breakpoints**:
- AnalyticsView.swift:54 - Test method call
- AnalyticsViewModel.swift:274 - Loading state
- AnalyticsViewModel.swift:284 - Insight set
- AIInsightCardView:502 - Insight display

**Xcode Debugging**:
```bash
# View all environment variables
po ProcessInfo.processInfo.environment

# Check API key value
po ProcessInfo.processInfo.environment["GEMINI_API_KEY"]

# Monitor view model state
po viewModel.aiInsight
po viewModel.aiInsightLoading
po viewModel.aiInsightError
```

---

## 📄 Code Snippets for Manual Testing

**Force Error State** (temporary):
```swift
#if DEBUG
func testAIInsight() async {
    await MainActor.run {
        aiInsightError = "Simulated error for testing"
        aiInsight = generateFallbackInsight()
        aiInsightLoading = false
    }
}
#endif
```

**Force Empty State** (temporary):
```swift
#if DEBUG
func testAIInsight() async {
    await MainActor.run {
        aiInsight = nil
        aiInsightLoading = false
    }
}
#endif
```

**Skip Loading Animation** (faster testing):
```swift
// Change sleep from 1.5s to 0.1s
try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
```

---

Generated: November 16, 2025
Status: Ready for Testing
Version: 1.0
