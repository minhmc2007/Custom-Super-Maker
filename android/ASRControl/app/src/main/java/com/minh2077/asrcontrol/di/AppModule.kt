package com.minh2077.asrcontrol.di

import com.minh2077.asrcontrol.data.repository.SystemRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideSystemRepository(): SystemRepository {
        return SystemRepository()
    }
}
