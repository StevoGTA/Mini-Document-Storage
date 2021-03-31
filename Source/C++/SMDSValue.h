//----------------------------------------------------------------------------------------------------------------------
//	SMDSValue.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#if 0

//----------------------------------------------------------------------------------------------------------------------
// MARK: SMDSValue

struct SMDSValue {
	// Type
	enum Type {
		kBool,
		kArrayOfStrings,
		kData,
		kDictionary,
		kFloat64,
		kSInt32,
		kSInt64,
		kString,
		kUInt32,
	};

	// Procs
	typedef	OI<SMDSValue>	(*Proc)(const CString& property, void* userData);

	// Methods
	public:
									// Lifecycle methods
									SMDSValue(bool value) : mType(kBool), mValue(value) {}
									SMDSValue(const TArray<CString>& value) : mType(kArrayOfStrings), mValue(value) {}
									SMDSValue(const CData& value) : mType(kData), mValue(value) {}
									SMDSValue(const CDictionary& value) : mType(kDictionary), mValue(value) {}
									SMDSValue(Float64 value) : mType(kFloat64), mValue(value) {}
									SMDSValue(SInt32 value) : mType(kSInt32), mValue(value) {}
									SMDSValue(SInt64 value) : mType(kSInt64), mValue(value) {}
									SMDSValue(const CString& value) : mType(kString), mValue(value) {}
									SMDSValue(UInt32 value) : mType(kUInt32), mValue(value) {}
									~SMDSValue()
										{
											// Check type
											if (mType == kArrayOfStrings) {
												// Cleanup array of strings
												Delete(mValue.mArrayOfStrings);
											} else if (mType == kData) {
												// Cleanup data
												Delete(mValue.mData);
											} else if (mType == kDictionary) {
												// Cleanup dictionary
												Delete(mValue.mDictionary);
											} else if (mType == kString) {
												// Cleanup string
												Delete(mValue.mString);
											}
										}

									// Instance methods
				Type				getType() const
										{ return mType; }

		const	TArray<CString>&	getArrayOfStrings() const
										{ return *mValue.mArrayOfStrings; }
				bool				getBool() const
										{ return mValue.mBool; }
		const	CData&				getData() const
										{ return *mValue.mData; }
		const	CDictionary&		getDictionary() const
										{ return *mValue.mDictionary; }
				Float64				getFloat64() const
										{ return mValue.mFloat64; }
				SInt32				getSInt32() const
										{ return mValue.mSInt32; }
				SInt64				getSInt64() const
										{ return mValue.mSInt64; }
		const	CString&			getString() const
										{ return *mValue.mString; }
				UInt32				getUInt32() const
										{ return mValue.mUInt32; }

	// Properties
	private:
		Type	mType;
		union Value {
			//  Lifecycle methods
			Value(const TArray<CString>& value) : mArrayOfStrings(new TArray<CString>(value)) {}
			Value(bool value) : mBool(value) {}
			Value(const CData& value) : mData(new CData(value)) {}
			Value(const CDictionary& value) : mDictionary(new CDictionary(value)) {}
			Value(Float64 value) : mFloat64(value) {}
			Value(SInt32 value) : mSInt32(value) {}
			Value(SInt64 value) : mSInt64(value) {}
			Value(const CString& value) : mString(new CString(value)) {}
			Value(UInt32 value) : mUInt32(value) {}

			// Properties
			bool				mBool;
			TArray<CString>*	mArrayOfStrings;
			CData*				mData;
			CDictionary*		mDictionary;
			Float64				mFloat64;
			SInt32				mSInt32;
			SInt64				mSInt64;
			CString*			mString;
			UInt32				mUInt32;
		}		mValue;
};

#endif
